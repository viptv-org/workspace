# /work subagent brief

Every `/work` implementation subagent reads this file first. It is part of
the brief; the orchestrator's message adds the issue, worktree, branch and
repo-specific notes.

## Scope and safety

- Work only in your worktree. Never touch the main clones under the
  workspace root or another agent's worktree; several agents run at once.
- Read the workspace `AGENTS.md`. The owner's shell is fish: write helper
  scripts to a file and run them with bash, and redirect noisy output to a
  temp file and read it back.
- Skills live in `.agents/skills/` (implement, tdd, diagnosing-bugs,
  code-review, pr, resolving-merge-conflicts, playwright-cli, serve-avd).
  The issue lifecycle is `docs/agents/issue-tracker.md`.
- Anything unrelated you find becomes a new issue
  (`--label bug --label needs-triage`, see "Found a bug?" in
  `issue-tracker.md`), never a change on your branch.

## Job order

1. Read the issue with comments (`gh issue view <n> -R viptv-org/<repo>
   --comments`) and `.agents/skills/implement/SKILL.md`. Reproduce or
   confirm the cause first where the issue asks, then implement test-first
   with the `tdd` skill.
2. **Commit continuously:** after each green cycle or logical step, with
   `Refs #<n>` in each message and the commit attribution line, and push
   the branch regularly so an interruption never loses work.
3. Run the `code-review` skill against `origin/main` and fix what it finds.
4. `git merge origin/main`, then run the repo's **full checks once**
   (testing budget below).
5. Push and open the PR with a body following `.agents/skills/pr/SKILL.md`.
   The very last line is `Closes viptv-org/<repo>#<n>`. Don't merge: the
   orchestrator does.
6. If you can't finish (you need a device decision, credentials or an
   owner choice), comment why on the issue, swap `ready-for-agent` for
   `ready-for-human`, remove the assignee, and stop. Missing device
   evidence alone isn't a reason: open the PR and say what's outstanding.

Final report: the PR URL, each check command with pass/fail and counts,
device evidence, issues you filed, and anything you're unsure of.

## Testing budget

The shared build slots are the bottleneck.

- Run every Gradle or cargo build/test through
  `<workspace>/scripts/agents/heavy.sh <command>` (absolute path, since you run in a worktree), with
  Gradle `--max-workers=1`. It runs the command in one of two build slots
  (`VIPTV_HEAVY_SLOTS`, default 2), so at most two heavy builds run at once
  across all agents.
- While iterating, run targeted tests only (`--tests '<YourTest*>'`,
  `cargo test <filter>`), plus whatever proves the red step.
- Run the full suite **exactly once**, right before the PR, after merging
  `origin/main`. Rerun a known flaky test alone, never the whole suite.
- Gradle test runs keep the daemon: no `--no-daemon`, and add
  `-Dorg.gradle.daemon.idletimeout=900000`.
- Build release APKs only when your issue changes `androidApp/` or the
  build. Otherwise use `-Pviptv.abis=x86_64` debug builds.

## Devices

Most app issues verify with desktop tests and desktop/web screenshots only.
Use an emulator only when your issue's Verification section allows it.
Then:

- read the ignored `.local-device-testing.md` first and pass an explicit
  `-s <serial>` to every adb command;
- run the whole device session as one script under
  `flock /tmp/viptv-emulator.lock`;
- install with `adb install -r` only. Never uninstall the app, clear its
  data, or sign out or switch the owner's profile;
- use the dev instance's QA profile, never the owner's own profile. The
  dev instance's address and controls are in the ignored `.kmp-dev/`
  files;
- if the owner's account is on the device, skip that evidence and say so.

## Backend builds

Build each backend worktree into its own target directory:
`CARGO_TARGET_DIR=/srv/fast/rust-target-backend-<issue>`. The shared
`~/.cargo/config.toml` target resolves to the same test-binary paths for
every worktree, so parallel agents overwrote each other's binaries
(found 2026-10-27, backend#20). The orchestrator deletes the directory after
merge.
