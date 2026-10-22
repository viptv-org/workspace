# Issue tracker: GitHub Issues

Every piece of work is a GitHub issue in the repo that owns the change; infer
it from that repo's origin (`gh` does this inside a clone, otherwise pass
`-R viptv-org/<repo>`). Workspace coordination lives in `viptv-org/workspace`.
Read the ticket and comments before implementation; publish decisions and
remaining acceptance there rather than making a second local tracker. There is
no Project board: issue state, labels, linked branches and PRs are the whole
record. Requires `gh` >= 2.94 (`--type`, `--parent`, `--blocked-by`).

## Where state lives

Each fact has one owner; never record it a second way.

| Question | Owner |
|---|---|
| May an agent start? needs info? needs a human? rejected? | triage label (see `triage-labels.md`) |
| Bug or enhancement? | `bug` / `enhancement` label |
| Blocked? | native blocked-by dependency |
| Part of a larger piece of work? | native sub-issue of the parent |
| Being worked on? | linked branch (`gh issue develop --list`) and assignee |
| In review? | open PR that closes the issue |
| Finished? | issue closed by the merged PR, or closed as `wontfix` |

## Found a bug? File it

Any agent that finds a bug or loose end outside its current task files an
issue at once and keeps working on its own task. It never fixes the unrelated
problem on the current branch.

```bash
gh issue create -R viptv-org/<repo> --label bug --label needs-triage \
  --title "<symptom, in user terms>" --body-file /tmp/issue.md
```

The body says what happens, what should happen, repro steps or evidence
(command, log line, screenshot path), and where it was found. Mention it in
the session's final report. `/triage` turns it into an agent brief.

## Lifecycle of one issue

One issue, one branch, one PR. Unrelated fixes never share a branch.

**Pick up.** Take only open `ready-for-agent` issues that have no open
blocker and no linked branch:

```bash
gh search issues --owner viptv-org --state open --label ready-for-agent
gh api repos/viptv-org/<repo>/issues/<n> --jq .issue_dependencies_summary.blocked_by   # must be 0
gh issue develop --list <n> -R viptv-org/<repo>                                     # must be empty
gh issue view <n> -R viptv-org/<repo> --comments
```

**Start.** Branch from the issue so GitHub links them, then claim it:

```bash
gh issue develop <n> -R viptv-org/<repo> --name <kind>/<n>-<slug> --base main --checkout
gh issue edit <n> -R viptv-org/<repo> --add-assignee @me
```

`<kind>` is `fix`, `feature`, `chore`, `docs` or `research`, e.g.
`fix/142-undecodable-autoplay`. Parallel agents each use their own worktree
(`--worktree ../wt-<repo>-<n>`); never put two issues in one checkout.

**Work.** `/implement` (with `/tdd`), run the repo's checks from `AGENTS.md`,
commit with `Refs #<n>` in the message, then `/code-review` against
`origin/main`.

**Open the PR.** Body from the `/pr` template, last line
`Closes viptv-org/<repo>#<n>`. Only the PR carries the closing keyword.

```bash
git push -u origin <kind>/<n>-<slug>
gh pr create --base main --title "<imperative summary>" --body-file /tmp/pr.md
```

**Merge.** Agents may merge their own reviewed PRs with a merge commit once
the checks pass, then confirm the issue closed:

```bash
gh pr merge <pr> --merge --delete-branch
gh issue view <n> --json state --jq .state   # CLOSED
```

Closing keywords only fire on PRs into the default branch, so no integration
branches without the owner's approval. Merged is not deployed: deployment
still needs separate approval and the served-hash check in `AGENTS.md`.

## When a skill says "publish to the issue tracker"

Create the issue in the owning repo with its triage and category labels. Wire
structure natively: `--parent <n|url>` for a sub-issue, `--blocked-by
<n>,<n>` for blockers (create blockers first).

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Sweeps

```bash
gh search issues --owner viptv-org --state open --label bug          # every open bug
gh search issues --owner viptv-org --state open --label needs-triage # untriaged
gh search issues --owner viptv-org --state open --no-label           # never labelled
```

## Pull requests as a triage surface

**PRs as a request surface: no.** External PRs are not a triage queue. Agent
PRs are how an issue is delivered, not requests.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one issue labelled `wayfinder:map`; its
tickets are sub-issues.

- **Map**: `gh issue create --label wayfinder:map` with the Notes /
  Decisions-so-far / Fog body.
- **Child ticket**: `gh issue create --parent <map> --label wayfinder:<type>`
  (`research`/`prototype`/`grilling`/`task`).
- **Blocking**: native dependencies, `--blocked-by <n>` at creation or
  `gh issue edit <n> --add-blocked-by <m>` later. Open blockers are
  `issue_dependencies_summary.blocked_by`.
- **Frontier**: the map's open sub-issues with no open blocker, no assignee
  and no linked branch; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first
  write. All agents share the owner's account, so also comment which session
  claimed it.
- **Resolve**: comment the answer, close the issue, then append a context
  pointer (gist + link) to the map's Decisions-so-far.
