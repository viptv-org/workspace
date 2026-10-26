---
name: work
description: Work the VIPTV issue frontier on this machine - parallel worktrees, one subagent and PR per issue, merge, repeat.
disable-model-invocation: true
---

# Work

You are the **orchestrator**. You pick `ready-for-agent` issues, give each
its own worktree and implementation subagent, merge the PRs they open, and
refill until the frontier is empty. You do not write feature code yourself.
`docs/agents/issue-tracker.md` is the lifecycle this follows; read it, and
the owning repo's `AGENTS.md`/README before dispatching work in that repo.

Arguments narrow the run: issue refs (`app#12`), a repo name, or a
concurrency (`3 at a time`). Default: every repo, 3 issues in flight.

## Preflight

- `gh --version` is at least 2.94.
- Existing worktrees under `.worktrees/` and branches without an issue
  number predate this flow; leave them as they are.

## 1. Find the frontier

```bash
gh search issues --owner viptv-org --state open --label ready-for-agent \
  --json repository,number,title,assignees,url --limit 100
```

Keep an issue only when it has no assignee, no open blocker
(`gh api repos/viptv-org/<repo>/issues/<n> --jq .issue_dependencies_summary.blocked_by`
is 0) and no linked branch (`gh issue develop --list <n> -R viptv-org/<repo>`
is empty). Read each kept issue with `--comments`. An empty frontier ends
the run (step 6); mention any `needs-triage` issues as candidates for
`/triage`.

## 2. Pick a batch

Fill free slots up to the concurrency limit, oldest first. Two issues that
will touch the same screen, module or file run one after the other, never
side by side, so their PRs do not conflict.

## 3. Claim and create the worktree

Per issue, from the owning repo's main clone (`<kind>` is `fix`, `feature`,
`chore`, `docs` or `research`):

```bash
cd /home/vm/code/viptv-org/<repo>
git fetch origin
gh issue develop <n> --name <kind>/<n>-<slug> --base main --checkout \
  --worktree <worktree>
gh issue edit <n> --add-assignee @me
gh issue comment <n> --body "Claimed by /work; branch <kind>/<n>-<slug>."
```

`<worktree>` is `/home/vm/code/viptv-org/.worktrees/<repo>-<n>/<repo>`,
except for `backend`, which uses `/tmp/viptv-wt/backend-<n>/backend`: Zeron
probes new localhost ports inside the workspace and breaks backend tests.

A fresh `app` worktree needs, before it builds: `local.properties` copied
from the main `app` clone, `git submodule update --init native/core`, and
`RUSTUP_TOOLCHAIN=1.98.0` for Gradle. Pass these to the subagent.

## 4. Dispatch one subagent per issue

Agent tool, `model: opus`, `effort: high`, in the background. The brief is
the subagent's only context; give it:

- the issue URL, the worktree path, the branch, and the repo's checks
  (`AGENTS.md` per-repo table) plus any worktree bootstrap from step 3
- the job, in order:
  1. Read the issue and comments, and `.agents/skills/implement/SKILL.md`.
     Implement test-first with the `tdd` skill.
  2. Run every Gradle or cargo build/test as
     `flock /tmp/viptv-heavy-build.lock <command>` with Gradle
     `--max-workers=1`, so parallel agents take turns on heavy builds.
  3. Commit continuously: after each green TDD cycle or logical step, with
     `Refs #<n>` in each message, and push the branch regularly so an
     interruption (rate limit, crash) never loses work. When the work is
     done, run the `code-review` skill against `origin/main` and fix what
     it finds.
  4. Push the branch and open the PR: body from `.agents/skills/pr/SKILL.md`,
     last line `Closes viptv-org/<repo>#<n>`. It does not merge.
  5. Anything unrelated it finds becomes a new `bug` + `needs-triage` issue
     (`docs/agents/issue-tracker.md`, "Found a bug?"), never a change on
     this branch.
  6. If it cannot finish (needs a device, a decision, or credentials), it
     comments why on the issue, swaps `ready-for-agent` for
     `ready-for-human`, removes the assignee, and stops.
- its final report: PR URL, each check command with its pass/fail result,
  issues it filed, and anything it is unsure of.

## 5. Merge, one PR at a time

When a subagent reports:

1. **Gate.** `gh pr diff` contains only this issue's change, the body ends
   with the `Closes` line, and the report shows the repo's checks passing.
   On a gap, send the subagent back with the specific fix (SendMessage).
2. **Sync.** If `gh pr view <pr> --json mergeable` is not `MERGEABLE`, or
   main has moved in the files it touches: in the worktree,
   `git merge origin/main`, resolve conflicts with the
   `resolving-merge-conflicts` skill, rerun the checks, push.
3. **Merge.** `gh pr merge <pr> -R viptv-org/<repo> --merge --delete-branch`,
   then `gh issue view <n> -R viptv-org/<repo> --json state` reads `CLOSED`.
4. **Clean up.** `git -C <repo> worktree remove <worktree>`,
   `git -C <repo> branch -D <branch>`, and `git -C <repo> pull --ff-only`
   when the main clone is on a clean `main`. Then run any post-merge steps
   your local memory notes give for that repo.
5. **Refill.** Back to step 1: the merge may have unblocked issues.

Merged is not deployed. Deployment stays a separate, owner-approved step.

## 6. Finish

The run is done when the frontier is empty, no subagent is in flight, and
every issue you claimed is either closed by a merged PR or handed back as
`ready-for-human` with a comment. Report: merged PRs (`repo#pr` closes
`repo#n`), issues handed back and why, issues filed during the run, and
any worktree left behind.
