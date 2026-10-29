# /work subagent brief

Read this first. The orchestrator's message adds the issue, worktree and branch.
Also read the workspace `AGENTS.md` and the target repo's `AGENTS.md`.

## Rules

- Work only in your worktree. Several agents run at once; never touch the main
  clones or another agent's worktree.
- Anything unrelated you find becomes a new issue (`bug` + `needs-triage`,
  `docs/agents/issue-tracker.md`), never a change on your branch.
- Follow the comment and doc rules in the workspace `AGENTS.md`: no comments
  by default, no history, no screenshots committed.

## Edit-only mode

Unless the orchestrator says otherwise:

- Don't build, compile or run tests: no Gradle, cargo, heavy.sh, emulator or
  browser. The orchestrator's batch gate builds and tests after merging.
- Write the tests the issue asks for, but don't run them.
- Nothing checks your work before it merges, so re-read every changed file:
  imports, types, call sites, every exhaustive `when`/`match`, and other users
  of anything you rename.
- In `app` and `backend` your branch is based on `edge`: compare and merge
  against `origin/edge` and open the PR with `--base edge`. Other repos target
  `main`.

## Job order

1. Read the issue with comments: `gh issue view <n> -R viptv-org/<repo> --comments`.
2. Make the change. Commit after each logical step with `Refs #<n>` and the
   attribution line, and push often.
3. Review your own diff against the base branch and fix what you find.
4. Open the PR with a body following `.agents/skills/pr/SKILL.md`. Say it's
   unbuilt and untested. The last line is `Closes viptv-org/<repo>#<n>`. Don't merge.
5. If you can't finish (a device, credentials or an owner decision), comment
   why on the issue, swap `ready-for-agent` for `ready-for-human`, remove the
   assignee, and stop.
6. Send your final report to the orchestrator: the PR URL, issues you filed,
   anything you're unsure of.

## When you're allowed to build

Fix agents repairing a red gate, and anyone the orchestrator explicitly asks to
build:

- Run every Gradle or cargo command through
  `<workspace>/scripts/agents/heavy.sh <command>`, with Gradle
  `--max-workers=1 -Dorg.gradle.daemon.idletimeout=900000`.
- Backend builds use `CARGO_TARGET_DIR=/srv/fast/rust-target-backend-<issue>`.
- Don't poll a build with repeated tool calls: each call re-sends your whole
  context. Run it in the foreground, or wait inside one call
  (`while kill -0 $PID; do sleep 30; done`).
- Run targeted tests while iterating and the full checks once at the end.

## Devices

Only when the issue's verification section allows it:

- read the ignored `.local-device-testing.md` first and pass `-s <serial>` to
  every adb command;
- run the whole session as one script under `flock /tmp/viptv-emulator.lock`;
- install with `adb install -r` only; never uninstall, clear data, sign out or
  switch the owner's profile;
- use the dev instance's QA profile (controls in the ignored `.kmp-dev/`).
