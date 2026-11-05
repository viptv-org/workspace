# /work subagent brief

Read this first. The orchestrator's message adds the issue, worktree and branch.
Also read the workspace `AGENTS.md` and the target repo's `AGENTS.md`.

## Rules

- Work only in your worktree. Several agents run at once; never edit, build,
  check out, branch or stash in the main clones (`app`, `backend`, `core`,
  `design`, `playback-gateway`, the workspace root) or another agent's
  worktree: the batch gates build from the main clones. Never delete, re-clone
  or re-init anything outside your worktree; if git looks broken, stop and
  report.
- If `claim.sh` refuses an issue, it belongs to someone else: stop and report;
  never work in the worktree it names.
- Once your PR merges, the orchestrator removes your worktree. Never keep your
  shell inside a worktree whose PR is merging: run commands as
  `cd <path> && ...`, claim a fresh worktree for the next issue, and never
  recreate a deleted worktree path.
- Push your branch after every commit, so the work survives if the machine
  loses your worktree.
- Anything unrelated you find becomes a new issue (`bug` + `needs-triage`,
  `docs/agents/issue-tracker.md`), never a change on your branch.
- Follow the comment and doc rules in the workspace `AGENTS.md`: no comments
  by default, no history, no screenshots committed.
- Fix the class, not the instance: when the bug can recur elsewhere, make one
  shared fix and add a test that walks every place it applies.
- Never upload anything (screenshots, logs, files) to third-party hosts or
  paste services. Keep screenshots and renders under `/tmp` and give the
  orchestrator their paths.
- The machine is shared. Run every ad hoc script or helper as
  `timeout 120 prlimit --as=4000000000 <command>`, and never leave one running
  in the background: one runaway loop can starve every agent and gate.
  Browsers and JVMs reserve large address space and crash under `--as`; give
  them `timeout` only.

## Testing

Locally you prove your change; the PR's GitHub Actions check runs the full
suite.

- Run only the test classes that cover what you changed, through
  `<workspace>/scripts/agents/heavy.sh <command>`. Never run the full app
  `desktopTest` suite locally.
- Before you push, the change compiles, test sources included: app
  `:composeApp:compileTestKotlinDesktop` (a targeted `--tests` run compiles
  them); backend and core `cargo test --no-run` for the touched crate. Wait for
  a heavy.sh slot rather than skipping this.
- Gradle runs with `--max-workers=1 -Dorg.gradle.daemon.idletimeout=900000`.
  Backend builds use `CARGO_TARGET_DIR=/srv/fast/rust-target-backend-<issue>`.
- Don't poll a build with repeated tool calls: each call re-sends your whole
  context. Run it in the foreground, or wait inside one call
  (`while kill -0 $PID; do sleep 30; done`).
- Once targeted tests pass and the code compiles, push, open the PR and report
  with "CI pending". Don't watch the check; the orchestrator does and sends you
  any failure.
- In `app` and `backend` your branch is based on `edge`: compare and merge
  against `origin/edge` and open the PR with `--base edge`. Other repos target
  `main`. `playback-gateway` has no CI: run its full suite
  (`cargo test --locked --workspace`) and put the result in the PR body.

## UI changes

- A change to what the user sees starts with a `design` PR that updates the
  spec, `copy.md` and `components.md`; the app PR follows it.
- Render the changed surface with real-looking data at phone (390 wide) and
  desktop (1280 and 1440) widths, plus TV when it changes, from a throwaway
  `ImageComposeScene` test. Save the PNGs to `/tmp`, check them for clipping,
  wrapping and misalignment, and send the paths. Don't commit them.

## Job order

1. Read the issue with comments: `gh issue view <n> -R viptv-org/<repo> --comments`.
2. Make the change. Commit after each logical step with `Refs #<n>` and the
   attribution line, and push often.
3. Review your own diff against the base branch and fix what you find.
4. Open the PR with a body following `.agents/skills/pr/SKILL.md`, with the
   tests you ran as evidence. The last line is `Closes viptv-org/<repo>#<n>`.
   Don't merge.
5. If you can't finish (a device, credentials or an owner decision), comment
   why on the issue, swap `ready-for-agent` for `ready-for-human`, remove the
   assignee, and stop.
6. Send your final report to the orchestrator: the PR URL, the tests you ran,
   issues you filed, anything you're unsure of.

## Devices

Only when the issue or the orchestrator allows it:

- read the ignored `.local-device-testing.md` first and pass `-s <serial>` to
  every adb command;
- run the whole session as one script under `flock /tmp/viptv-emulator.lock`;
- install with `adb install -r` only; never uninstall, clear data, sign out or
  switch the owner's profile;
- use the dev instance's QA profile (controls in the ignored `.kmp-dev/`).
