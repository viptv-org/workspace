import datetime as dt
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import pitch  # noqa: E402

BOT = "900"
NOW = dt.datetime(2026, 11, 6, 12, 0, tzinfo=dt.timezone.utc)


class FakeDiscord:
    def __init__(self):
        self.next_id = 1000
        self.channels = {}
        self.reactions = {}
        self.threads = {}

    def _id(self):
        self.next_id += 1
        return str(self.next_id)

    def me(self):
        return BOT

    def post(self, channel, content, files=()):
        mid = self._id()
        self.channels.setdefault(channel, []).append(
            {"id": mid, "content": content, "files": list(files), "author": {"id": BOT},
             "timestamp": NOW.isoformat()})
        return mid

    def thread(self, channel, message, name):
        tid = self._id()
        self.threads[tid] = name
        return tid

    def react(self, channel, message):
        self.reactions.setdefault(message, []).append(BOT)

    def reactors(self, channel, message):
        return [u for u in self.reactions.get(message, []) if u != BOT]

    def messages(self, channel, after=None):
        msgs = [m for m in self.channels.get(channel, []) if not after or int(m["id"]) > int(after)]
        return list(reversed(msgs))

    def human_reply(self, channel, content):
        self.channels.setdefault(channel, []).append(
            {"id": self._id(), "content": content, "author": {"id": "1"}, "timestamp": NOW.isoformat()})


class FakeGitHub:
    def __init__(self):
        self.comments_by_issue = {}
        self.label_sets = {}

    def comments(self, repo, n):
        return self.comments_by_issue.get((repo, str(n)), [])

    def comment(self, repo, n, body):
        self.comments_by_issue.setdefault((repo, str(n)), []).append({"body": body})

    def labels(self, repo, n):
        return sorted(self.label_sets.setdefault((repo, str(n)), {"ready-for-agent"}))

    def relabel(self, repo, n, add, remove):
        labels = self.label_sets.setdefault((repo, str(n)), {"ready-for-agent"})
        labels.difference_update(remove)
        labels.add(add)

    def awaiting_human(self):
        return [[r, int(n)] for (r, n), labels in self.label_sets.items() if "ready-for-human" in labels]


class PitchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.images = []
        for name in ("a.png", "b.png"):
            path = os.path.join(self.tmp.name, name)
            with open(path, "wb") as f:
                f.write(b"\x89PNG")
            self.images.append(path)
        self.discord, self.github = FakeDiscord(), FakeGitHub()
        self.clock = [NOW]
        self.pitches = pitch.Pitches(self.discord, self.github, "chan", "<@1> <@2>", now=lambda: self.clock[0])

    def tearDown(self):
        self.tmp.cleanup()

    def spec(self, issue=7, **over):
        s = {"repo": "app", "issue": issue, "title": "Home rail", "question": "Which rail layout?", "default": "B",
             "options": [{"key": "A", "name": "Dense grid", "why": "More titles.\nHarder on TV.", "images": [self.images[0]]},
                         {"key": "B", "name": "Rail with peek", "why": "Shows there is more.", "images": [self.images[1]]}]}
        s.update(over)
        return s

    def test_post_mentions_maintainers_uploads_images_and_records_on_issue(self):
        self.pitches.post(self.spec())
        header = self.discord.channels["chan"][0]["content"]
        self.assertTrue(header.startswith(pitch.HEADER_PREFIX))
        self.assertIn("<@1> <@2>", header)
        self.assertIn("app#7", header)
        thread = next(iter(self.discord.threads))
        option_msgs = self.discord.channels[thread]
        self.assertEqual([m["files"] for m in option_msgs], [[self.images[0]], [self.images[1]]])
        self.assertIn("(recommended)", option_msgs[1]["content"])
        record, resolved = self.pitches.record("app", 7)
        self.assertEqual((record["default"], record["deadline"], resolved), ("B", "2026-11-08T12:00:00Z", False))
        self.assertEqual(self.github.labels("app", 7), ["ready-for-human"])

    def test_status_reports_waiting_then_expired_default(self):
        self.pitches.post(self.spec())
        self.assertEqual(self.pitches.status("app", 7)[0], "waiting")
        self.clock[0] = NOW + dt.timedelta(hours=48)
        self.assertEqual(self.pitches.status("app", 7), ("expired", "B"))

    def test_status_reads_a_maintainer_reaction(self):
        self.pitches.post(self.spec())
        record, _ = self.pitches.record("app", 7)
        self.discord.reactions[record["options"]["A"]].append("1")
        self.assertEqual(self.pitches.status("app", 7), ("picked", "A"))
        self.discord.reactions[record["options"]["B"]].append("2")
        self.assertEqual(self.pitches.status("app", 7), ("split", "A,B"))

    def test_a_reply_beats_reactions(self):
        self.pitches.post(self.spec())
        record, _ = self.pitches.record("app", 7)
        self.discord.reactions[record["options"]["A"]].append("1")
        self.discord.human_reply(record["thread"], "B with A's header")
        self.assertEqual(self.pitches.status("app", 7), ("replied", "B with A's header"))

    def test_resolve_records_decision_and_hands_back_to_agents(self):
        self.pitches.post(self.spec())
        self.pitches.resolve("app", 7, "A", "owner picked")
        self.assertEqual(self.pitches.status("app", 7), ("resolved", None))
        self.assertEqual(self.github.labels("app", 7), ["ready-for-agent"])
        self.assertIn("Decision: A", self.github.comments("app", 7)[-1]["body"])
        self.assertEqual(self.pitches.open(), [])
        with self.assertRaises(pitch.PitchError):
            self.pitches.resolve("app", 7, "A")

    def test_resolve_after_deadline_says_default(self):
        self.pitches.post(self.spec())
        self.clock[0] = NOW + dt.timedelta(hours=49)
        self.pitches.resolve("app", 7, "B")
        self.assertIn("default after 48 h", self.github.comments("app", 7)[-1]["body"])

    def test_a_second_open_pitch_on_one_issue_is_refused_until_resolved(self):
        self.pitches.post(self.spec())
        with self.assertRaises(pitch.PitchError):
            self.pitches.post(self.spec())
        self.pitches.resolve("app", 7, "B")
        self.pitches.post(self.spec())

    def test_weekly_cap_refuses_the_fifteenth_pitch(self):
        for n in range(pitch.WEEKLY_CAP):
            self.pitches.post(self.spec(issue=100 + n))
        with self.assertRaisesRegex(pitch.PitchError, "weekly cap"):
            self.pitches.post(self.spec(issue=200))

    def test_pitches_older_than_a_week_do_not_count(self):
        for n in range(pitch.WEEKLY_CAP):
            self.pitches.post(self.spec(issue=100 + n))
        for m in self.discord.channels["chan"]:
            m["timestamp"] = (NOW - dt.timedelta(days=8)).isoformat()
        self.pitches.post(self.spec(issue=200))

    def test_open_lists_only_pitched_issues(self):
        self.github.label_sets[("backend", "3")] = {"ready-for-human"}
        self.pitches.post(self.spec())
        self.assertEqual([line.split("\t")[:2] for line in self.pitches.open()], [["app#7", "waiting"]])

    def test_spec_validation(self):
        bad = [
            self.spec(default="C"),
            self.spec(options=self.spec()["options"][:1]),
            self.spec(options=[dict(o, why="1\n2\n3\n4") for o in self.spec()["options"]]),
            self.spec(options=[dict(o, images=["/nonexistent.png"]) for o in self.spec()["options"]]),
        ]
        for spec in bad:
            with self.assertRaises(pitch.PitchError):
                pitch.validate(spec)


class DiscordTransportTest(unittest.TestCase):
    def test_multipart_upload_carries_payload_and_files(self):
        sent = []

        def send(method, url, headers, body):
            sent.append((method, url, headers, body))
            return 200, json.dumps({"id": "5"}).encode()

        with tempfile.NamedTemporaryFile(suffix=".png") as f:
            f.write(b"PNGDATA")
            f.flush()
            pitch.Discord("tok", send).post("chan", "hi", [f.name])
        method, url, headers, body = sent[0]
        self.assertEqual((method, url), ("POST", pitch.API + "/channels/chan/messages"))
        self.assertEqual(headers["Authorization"], "Bot tok")
        self.assertIn(b'name="files[0]"', body)
        self.assertIn(b"PNGDATA", body)
        self.assertIn(b'"attachments"', body)

    def test_rate_limit_is_retried(self):
        replies = [(429, b'{"retry_after": 0}'), (200, b'{"id": "9"}')]
        d = pitch.Discord("tok", lambda *a: replies.pop(0))
        self.assertEqual(d.call("GET", "/users/@me")["id"], "9")

    def test_reactors_exclude_the_bot(self):
        def send(method, url, headers, body):
            if url.endswith("/users/@me"):
                return 200, b'{"id": "900"}'
            return 200, json.dumps([{"id": "900"}, {"id": "1"}, {"id": "7", "bot": True}]).encode()

        self.assertEqual(pitch.Discord("tok", send).reactors("t", "m"), ["1"])


if __name__ == "__main__":
    unittest.main()
