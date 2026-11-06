---
name: pitch
description: Ask the VIPTV maintainers to pick between rendered design options in Discord, with a 48-hour default. Use from /work when a broad, user-visible choice needs a human.
---

# Pitch

A pitch shows the maintainers 2–4 rendered options with short reasoning, the
way a designer would present them, and lets them pick in Discord. GitHub keeps
the record. Pitches never block: if no one answers within 48 hours, the
recommended default stands.

## When

Pitch only when all of these hold. Otherwise decide yourself and note the
choice in the PR.

- Users see the result, and changing it later is expensive (a screen layout,
  navigation, a visual style).
- The `design` specs don't already answer it.
- Fewer than 14 pitches went out in the last 7 days. `pitch.py post` refuses
  the 15th; decide that one yourself and list it in your report so the owner
  can overrule it.

Only the `/work` orchestrator posts pitches. A subagent that hits such a
choice proposes a pitch in its report (the question, options, renders, its
pick) and stops. The orchestrator either posts it or tells the agent to go
with its pick.

## Make the options

- Render each option from a throwaway `ImageComposeScene` test with real data
  from the dev instance: phone 390 wide, desktop 1280 and 1440, plus TV when it
  changes. Save PNGs under `/tmp`.
- Real titles and artwork are fine. Never show secrets, provider or stream
  URLs, hosts, tokens, emails, or account and profile names: crop or blank them.
- Per option: a letter, a short name, its images, and at most 3 lines: what it
  is, why, what it costs or risks. Recommend one as the default.

## Post

```bash
scripts/agents/pitch.py post /tmp/pitch-<repo>-<n>.json
```

```json
{"repo": "app", "issue": 123, "title": "Home rail layout",
 "question": "How should the home rails show that there is more to scroll?",
 "default": "B",
 "options": [
  {"key": "A", "name": "Dense grid", "why": "Shows the most titles.\nHard to scan with a TV remote.",
   "images": ["/tmp/pitch-app-123/a-phone.png", "/tmp/pitch-app-123/a-tv.png"]},
  {"key": "B", "name": "Rail with peek", "why": "The next card's edge shows there is more.\nOne extra layout pass.",
   "images": ["/tmp/pitch-app-123/b-phone.png"]}]}
```

The command posts the question in the pitch channel with the maintainers
mentioned and opens a thread with one message per option, its images
attached. It records the pitch on the issue and swaps `ready-for-agent` for
`ready-for-human`. Maintainers pick by reacting 👍 on an option or replying in
the thread.

## Resolve

Every queue check runs:

```bash
scripts/agents/pitch.py open      # <repo>#<n>  picked|replied|split|expired|waiting  <detail>
```

- `picked X` or `expired X`: `pitch.py resolve <repo> <n> X`.
- `replied <text>`: read the reply, then resolve with the option it names and
  the rest as the note, e.g. `resolve app 123 B "use A's header"`.
- `split A,B`: the maintainers disagree. Leave it until one replies; when it
  expires, resolve with the default.
- `waiting`: nothing to do.

`resolve` comments the decision on the issue, sets `ready-for-agent` again
and posts the decision in the thread. The issue keeps its claim and branch,
so `frontier.sh` won't list it again: send the decision to the agent that
proposed the pitch, or dispatch a new agent on the same worktree and branch.

## Setup (once, by the owner)

1. At https://discord.com/developers/applications create an application, open
   **Bot**, reset and copy the token, and turn on **Message Content Intent**.
2. Invite it with
   `https://discord.com/oauth2/authorize?client_id=<application id>&scope=bot&permissions=309237746752`
   (view channels, send messages, attach files, add reactions, read history,
   create public threads, send in threads).
3. Make a text channel for pitches. With Developer Mode on, copy its ID and
   each maintainer's user ID.
4. In the root `.env` on every machine that runs `/work`:
   ```
   DISCORD_BOT_TOKEN=<token>
   DISCORD_PITCH_CHANNEL=<channel id>
   DISCORD_MENTIONS=<@owner id> <@vynxc id>
   ```
5. `scripts/agents/pitch.py check` prints `ok`.
