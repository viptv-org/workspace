#!/usr/bin/env python3
"""Ask the maintainers to pick between rendered options, in Discord.

Usage:
  pitch.py post <spec.json>             open a pitch (see .agents/skills/pitch/SKILL.md)
  pitch.py status <repo> <issue>        picked X | replied | split | expired | waiting | resolved
  pitch.py resolve <repo> <issue> <option> [note]
  pitch.py open                         every open pitch and its status
  pitch.py check                        verify the bot token and channel
"""
import datetime as dt
import json
import mimetypes
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

API = "https://discord.com/api/v10"
THUMBS = "\N{THUMBS UP SIGN}"
WEEKLY_CAP = 14
DEADLINE = dt.timedelta(hours=48)
MARKER = "viptv-pitch"
RESOLVED = "viptv-pitch-resolved"
HEADER_PREFIX = "\N{BALLOT BOX WITH BALLOT} **Pitch"
ORG = "viptv-org"


class PitchError(Exception):
    pass


def load_env():
    env, d = {}, os.path.dirname(os.path.abspath(__file__))
    while True:
        try:
            with open(os.path.join(d, ".env")) as f:
                for line in f:
                    m = re.match(r"\s*(?:export\s+)?(DISCORD_[A-Z0-9_]*)=(.*)", line)
                    if m:
                        env.setdefault(m.group(1), m.group(2).strip().strip("'\""))
        except OSError:
            pass
        if os.path.dirname(d) == d:
            break
        d = os.path.dirname(d)
    env.update({k: v for k, v in os.environ.items() if k.startswith("DISCORD_")})
    return env


class Discord:
    def __init__(self, token, send=None):
        self.token = token
        self.send = send or self._urllib_send
        self._me = None

    def _urllib_send(self, method, url, headers, body):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()

    def call(self, method, path, payload=None, files=()):
        headers = {"Authorization": f"Bot {self.token}",
                   "User-Agent": "DiscordBot (https://github.com/viptv-org/workspace, 1)"}
        body = None
        if files:
            boundary = uuid.uuid4().hex
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
            body = multipart(boundary, payload or {}, files)
        elif payload is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(payload).encode()
        for _ in range(5):
            status, raw = self.send(method, API + path, headers, body)
            if status == 429:
                time.sleep(float(json.loads(raw or b"{}").get("retry_after", 1)))
                continue
            if status >= 400:
                raise PitchError(f"Discord {method} {path}: {status} {raw[:300]!r}")
            return json.loads(raw) if raw else None
        raise PitchError(f"Discord {method} {path}: still rate limited")

    def me(self):
        if self._me is None:
            self._me = self.call("GET", "/users/@me")["id"]
        return self._me

    def post(self, channel, content, files=()):
        payload = {"content": content, "allowed_mentions": {"parse": ["users"]}}
        if files:
            payload["attachments"] = [{"id": i, "filename": os.path.basename(p)} for i, p in enumerate(files)]
        return self.call("POST", f"/channels/{channel}/messages", payload, files)["id"]

    def thread(self, channel, message, name):
        return self.call("POST", f"/channels/{channel}/messages/{message}/threads",
                         {"name": name[:100], "auto_archive_duration": 4320})["id"]

    def react(self, channel, message):
        self.call("PUT", f"/channels/{channel}/messages/{message}/reactions/{urllib.parse.quote(THUMBS)}/@me")

    def reactors(self, channel, message):
        users = self.call("GET", f"/channels/{channel}/messages/{message}/reactions/{urllib.parse.quote(THUMBS)}?limit=100")
        return [u["id"] for u in users if u["id"] != self.me() and not u.get("bot")]

    def messages(self, channel, after=None):
        query = "?limit=100" + (f"&after={after}" if after else "")
        return self.call("GET", f"/channels/{channel}/messages{query}")


def multipart(boundary, payload, files):
    out = [f"--{boundary}\r\nContent-Disposition: form-data; name=\"payload_json\"\r\n"
           f"Content-Type: application/json\r\n\r\n{json.dumps(payload)}\r\n".encode()]
    for i, path in enumerate(files):
        with open(path, "rb") as f:
            data = f.read()
        kind = mimetypes.guess_type(path)[0] or "application/octet-stream"
        out.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"files[{i}]\"; "
                   f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: {kind}\r\n\r\n".encode() + data + b"\r\n")
    out.append(f"--{boundary}--\r\n".encode())
    return b"".join(out)


class GitHub:
    def __init__(self, run=None):
        self.run = run or self._gh

    def _gh(self, *args):
        r = subprocess.run(["gh", *args], capture_output=True, text=True)
        if r.returncode:
            raise PitchError(f"gh {' '.join(args[:3])}: {r.stderr.strip()}")
        return r.stdout

    def comments(self, repo, n):
        return json.loads(self.run("api", f"repos/{ORG}/{repo}/issues/{n}/comments", "--paginate",
                                   "--jq", "[.[] | {body, created_at}]") or "[]")

    def comment(self, repo, n, body):
        self.run("issue", "comment", str(n), "-R", f"{ORG}/{repo}", "--body", body)

    def labels(self, repo, n):
        return json.loads(self.run("issue", "view", str(n), "-R", f"{ORG}/{repo}", "--json", "labels",
                                   "--jq", "[.labels[].name]"))

    def relabel(self, repo, n, add, remove):
        have = self.labels(repo, n)
        args = ["issue", "edit", str(n), "-R", f"{ORG}/{repo}", "--add-label", add]
        for label in remove:
            if label in have:
                args += ["--remove-label", label]
        self.run(*args)

    def awaiting_human(self):
        return json.loads(self.run("search", "issues", "--owner", ORG, "--state", "open", "--label", "ready-for-human",
                                   "--limit", "200", "--json", "repository,number",
                                   "--jq", "[.[] | [.repository.name, .number]]") or "[]")


def parse_iso(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def validate(spec):
    for key in ("repo", "issue", "title", "question", "default", "options"):
        if key not in spec:
            raise PitchError(f"spec is missing {key!r}")
    keys = [o.get("key") for o in spec["options"]]
    if not 2 <= len(keys) <= 4 or len(set(keys)) != len(keys):
        raise PitchError("a pitch has 2 to 4 options with distinct keys")
    if spec["default"] not in keys:
        raise PitchError(f"default {spec['default']!r} is not one of {keys}")
    for o in spec["options"]:
        if not o.get("name") or not o.get("why"):
            raise PitchError(f"option {o['key']} needs a name and a why")
        if len(o["why"].strip().splitlines()) > 3:
            raise PitchError(f"option {o['key']}: at most 3 lines of reasoning")
        images = o.get("images", [])
        if not 1 <= len(images) <= 10:
            raise PitchError(f"option {o['key']}: 1 to 10 images")
        for p in images:
            if not os.path.isfile(p):
                raise PitchError(f"option {o['key']}: no such image {p}")
            if os.path.getsize(p) > 10 * 1024 * 1024:
                raise PitchError(f"option {o['key']}: {p} is over Discord's 10 MB limit")


class Pitches:
    def __init__(self, discord, github, channel, mentions, now=None):
        self.discord, self.github = discord, github
        self.channel, self.mentions = channel, mentions
        self.now = now or (lambda: dt.datetime.now(dt.timezone.utc))

    def pitches_this_week(self):
        since = self.now() - dt.timedelta(days=7)
        return sum(1 for m in self.discord.messages(self.channel)
                   if m["author"]["id"] == self.discord.me() and m["content"].startswith(HEADER_PREFIX)
                   and parse_iso(m["timestamp"]) > since)

    def record(self, repo, n):
        pitch, resolved = None, False
        for c in self.github.comments(repo, n):
            m = re.search(rf"<!-- {MARKER} (\{{.*?\}}) -->", c["body"])
            if m:
                pitch, resolved = json.loads(m.group(1)), False
            elif f"<!-- {RESOLVED} -->" in c["body"] and pitch:
                resolved = True
        return pitch, resolved

    def post(self, spec):
        validate(spec)
        repo, n = spec["repo"], spec["issue"]
        pitch, resolved = self.record(repo, n)
        if pitch and not resolved:
            raise PitchError(f"{repo}#{n} already has an open pitch")
        used = self.pitches_this_week()
        if used >= WEEKLY_CAP:
            raise PitchError(f"weekly cap reached ({used}/{WEEKLY_CAP}): decide this one yourself and report it")
        deadline = self.now() + DEADLINE
        unix = int(deadline.timestamp())
        url = f"https://github.com/{ORG}/{repo}/issues/{n}"
        header = self.discord.post(self.channel, (
            f"{HEADER_PREFIX} · {repo}#{n} · {spec['title']}** {self.mentions}".rstrip() + "\n"
            f"{spec['question']}\n"
            f"Default **{spec['default']}** unless you pick <t:{unix}:R> (<t:{unix}:f>). "
            f"React {THUMBS} on an option or reply in the thread.\n<{url}>"))
        thread = self.discord.thread(self.channel, header, f"{repo}#{n} {spec['title']}")
        options = {}
        for o in spec["options"]:
            mark = " (recommended)" if o["key"] == spec["default"] else ""
            mid = self.discord.post(thread, f"**{o['key']} — {o['name']}**{mark}\n{o['why'].strip()}", o["images"])
            self.discord.react(thread, mid)
            options[o["key"]] = mid
        record = {"channel": self.channel, "header": header, "thread": thread, "options": options,
                  "default": spec["default"], "deadline": deadline.strftime("%Y-%m-%dT%H:%M:%SZ")}
        lines = [f"**Pitch in Discord:** {spec['question']}", ""]
        lines += [f"- **{o['key']} — {o['name']}**: {' '.join(o['why'].split())}" for o in spec["options"]]
        lines += ["", f"Default **{spec['default']}** stands at {record['deadline']} unless a maintainer picks another.",
                  f"<!-- {MARKER} {json.dumps(record, separators=(',', ':'))} -->"]
        self.github.comment(repo, n, "\n".join(lines))
        self.github.relabel(repo, n, "ready-for-human", ["ready-for-agent", "needs-pitch"])
        return f"posted {repo}#{n}: thread {thread}, default {spec['default']}, decides itself {record['deadline']}"

    def status(self, repo, n):
        pitch, resolved = self.record(repo, n)
        if not pitch:
            return "none", None
        if resolved:
            return "resolved", None
        thread = pitch["thread"]
        last = max(pitch["options"].values(), key=int)
        replies = [m["content"] for m in self.discord.messages(thread, after=last)
                   if m["author"]["id"] != self.discord.me() and not m["author"].get("bot") and m["content"].strip()]
        if replies:
            return "replied", " | ".join(reversed(replies))
        picked = [k for k, mid in pitch["options"].items() if self.discord.reactors(thread, mid)]
        if len(picked) == 1:
            return "picked", picked[0]
        if len(picked) > 1:
            return "split", ",".join(picked)
        if self.now() >= parse_iso(pitch["deadline"]):
            return "expired", pitch["default"]
        return "waiting", pitch["deadline"]

    def resolve(self, repo, n, option, note=""):
        pitch, resolved = self.record(repo, n)
        if not pitch or resolved:
            raise PitchError(f"{repo}#{n} has no open pitch")
        if option not in pitch["options"]:
            raise PitchError(f"{option!r} is not one of {list(pitch['options'])}")
        how = "default after 48 h" if option == pitch["default"] and self.now() >= parse_iso(pitch["deadline"]) else "decided"
        text = f"**Decision: {option}** ({how}){': ' + note if note else ''}"
        self.github.comment(repo, n, f"{text}\n<!-- {RESOLVED} -->")
        self.github.relabel(repo, n, "ready-for-agent", ["ready-for-human"])
        self.discord.post(pitch["thread"], text)
        return f"resolved {repo}#{n}: {option}"

    def open(self):
        out = []
        for repo, n in self.github.awaiting_human():
            state, detail = self.status(repo, n)
            if state not in ("none", "resolved"):
                out.append(f"{repo}#{n}\t{state}\t{detail}")
        return out


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if len(argv) > 1 else 2
    env = load_env()
    missing = [k for k in ("DISCORD_BOT_TOKEN", "DISCORD_PITCH_CHANNEL") if not env.get(k)]
    if missing:
        print(f"missing {', '.join(missing)} in the root .env (setup: .agents/skills/pitch/SKILL.md)", file=sys.stderr)
        return 2
    discord = Discord(env["DISCORD_BOT_TOKEN"])
    pitches = Pitches(discord, GitHub(), env["DISCORD_PITCH_CHANNEL"], env.get("DISCORD_MENTIONS", ""))
    cmd, args = argv[1], argv[2:]
    try:
        if cmd == "post" and len(args) == 1:
            with open(args[0]) as f:
                print(pitches.post(json.load(f)))
        elif cmd == "status" and len(args) == 2:
            state, detail = pitches.status(args[0], args[1])
            print(f"{state}\t{detail}" if detail else state)
        elif cmd == "resolve" and len(args) >= 3:
            print(pitches.resolve(args[0], args[1], args[2], " ".join(args[3:])))
        elif cmd == "open" and not args:
            print("\n".join(pitches.open()) or "no open pitches")
        elif cmd == "check" and not args:
            discord.me()
            discord.messages(env["DISCORD_PITCH_CHANNEL"])
            print(f"ok: bot can read the pitch channel; {pitches.pitches_this_week()}/{WEEKLY_CAP} pitches this week")
        else:
            print(__doc__.strip(), file=sys.stderr)
            return 2
    except PitchError as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
