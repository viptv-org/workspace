---
name: intake
description: File the owner's bugs, ideas and requests as GitHub issues in the VIPTV issue flow.
disable-model-invocation: true
---

# Intake

Turn what the owner describes (one bug or a messy brain-dump) into
well-formed GitHub issues that `/work` can pick up. You file; you never fix.
`docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` are the
rules; read both first.

## 1. Split

Break the message into **items**: one item per independent problem or
request. Two symptoms with one cause are one item; one sentence asking for
two unrelated things is two. Done when every sentence of the owner's
message maps to an item or is noted as context.

## 2. Place and de-duplicate each item

- **Owning repo**: the repo table in `AGENTS.md`; client UI and playback on
  devices is `app`.
- **Duplicate check**: `gh search issues --owner viptv-org "<keywords>"`
  (open and recently closed). A match gets a comment with the new
  information instead of a new issue.
- **Already fixed?** Look at the relevant code on `origin/main` long enough
  to name the area and confirm the problem is still there. Reproduce when
  it is cheap.

## 3. Ask, while the owner is here

Anything you would otherwise label `needs-info` gets asked now, in one
batch of questions. Use `needs-info` only for what the owner cannot answer
either.

## 4. Shape and label

| Item | Labels | Body |
|---|---|---|
| clear scope and checkable acceptance criteria | `ready-for-agent` + `bug`/`enhancement` | agent brief per `.agents/skills/triage/AGENT-BRIEF.md` |
| needs a device, physical TV, credentials or a design/product decision | `ready-for-human` + category | same brief, plus why an agent cannot do it |
| unclear after asking | `needs-triage` + category | what is known and what is open |
| too big for one agent session | parent issue + one sub-issue per slice | slice it as tracer bullets per `.agents/skills/to-tickets/SKILL.md` steps 3 and 5; each slice `ready-for-agent`, wired with `--parent` and `--blocked-by`, blockers created first |

Bug bodies carry: what happens, what should happen, repro steps or
evidence, and where it was seen (device, build, screen).

Most VIPTV repos are public. Bodies contain no secrets, tokens, private
addresses, device values, provider URLs or account details; describe them
generically ("the owner's Stremio account").

## 5. File and report

Create each issue with `gh issue create -R viptv-org/<repo> --label ...
--body-file <file>`. Then report one line per item: `repo#n`, title,
labels, and the URL, plus any duplicates you commented on. Done when every
item from step 1 is an issue or a comment on an existing one.
