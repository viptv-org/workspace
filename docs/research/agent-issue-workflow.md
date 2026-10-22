# Agent work tracking: Issues + one org Project, one branch and one PR per fix

Date: 2026-10-22. Status: research only; `docs/agents/*` and the AGENTS files own any resulting rule.

Evidence rule: every claim cites a local file (with line numbers, read 2026-10-22), a
docs.github.com / cli.github.com page, or a GitHub CLI release note, or is marked **unverified**.
Facts about the VIPTV org marked "(checked live)" come from read-only `gh api` / `gh --help`
calls on this machine on 2026-10-22. No Project, issue, label or branch was created.

Decided by the owner and not revisited here: every piece of work is a real issue in its owning
repo, added to one org-wide Project; draft-only cards are rejected; each unrelated fix gets its
own branch and its own pull request.

**Outcome (2026-10-22):** after reading this, the owner chose **issues only, no Project board for
now**. Linked branches, open PRs and closed state already carry the stage a board would show, and a
board on the Free plan is a second list that issues can silently miss. A board can be added later
on top of the same issues. Also decided: agents merge their own reviewed PRs with merge commits;
category stays on the `bug`/`enhancement` labels. `gh` was upgraded to 2.100.0. The adopted rules
live in `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`.

## Summary

1. **The vendored skills already want GitHub-native structure, but they stop at the issue.**
   `to-tickets` publishes tracer-bullet issues with native blocking links and the
   `ready-for-agent` label; `wayfinder` uses sub-issues, native dependencies and an assignee claim.
   None of `implement`, `code-review` or `pr` creates a branch, pushes, or opens a PR, and none
   mentions a Project. All of that has to be supplied by `docs/agents/issue-tracker.md`, which the
   skills are written to consult, so no vendored skill needs editing.
2. **Do not store the same state twice. Give each question one owner.** Triage role (who may act:
   `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) stays in the
   labels the skills already speak. Execution stage (Backlog, In progress, In review, Done) lives
   only in the Project `Status` field. "Blocked" lives only in the native blocked-by edge. Category
   (bug/feature/task) lives only in the org Issue type. Nothing is a column and a label at once.
3. **Org plan is Free (checked live), so Project auto-add is nearly useless here.** Free allows one
   auto-add workflow, and each workflow targets one repository. VIPTV has about a dozen active
   repos. Agents must add every issue to the Project themselves; auto-add is at most a safety net
   for one repo.
4. **The installed `gh` (2.81.0, checked live) is too old.** Name-based `gh project item-edit` needs
   2.97; `--type`, `--parent`, `--blocked-by` need 2.94; `gh issue develop --worktree` needs 2.99.
   2.97 also fixes four security advisories. Upgrade before anything else.
5. **The "closed → Done" and "merged → Done" built-in workflows are on by default and are enough to
   finish an issue.** A PR body with `Closes viptv-org/<repo>#N` against the default branch closes the
   issue on merge, which flips Status to Done. Keywords are ignored for PRs that target a
   non-default branch, which conflicts with the `to-tickets` integration-branch exception.
6. **Workflows and views cannot be created from the CLI.** `gh project` has no workflow or view
   creation subcommand. The owner sets up views and workflows once in the web UI.

## Current state in VIPTV

- `docs/agents/issue-tracker.md:1-9` says use existing GitHub Issues in the owning repo, comment
  decisions there, "PRs as a request surface: no". `docs/agents/triage-labels.md:1-6` is the
  identity mapping of the five roles. Neither mentions Projects, sub-issues, dependencies, issue
  types, branches or PRs. The Wayfinding section that the template carries
  (`.agents/skills/setup-matt-pocock-skills/issue-tracker-github.md:36-45`) is absent from the
  local file even though `wayfinder` tells the agent to consult it
  (`.agents/skills/wayfinder/SKILL.md:25`).
- `AGENTS.md` ("Start here" step 4) says run the checks, "then commit and push its branch". It says
  nothing about PRs. `docs/agents/handoff.md:24-25` records that "Agents may merge reviewed PRs to
  `main` (decision recorded 2026-09-30); deployment and destructive migration still need separate
  approval". `AGENTS.md:86-87` says never claim a change is live without checking the served asset
  hash. So **Done must mean merged, not deployed.**
- Org facts (checked live): plan `free`; org-level Issue types already exist and are enabled
  (Task, Bug, Feature); the `gh` token has the `project` scope; `gh` is 2.81.0.

---

## 1. What the vendored skills prescribe

All paths under `.agents/skills/`.

### Slices, edges, parents, frontier

- **Tracer bullets.** `to-tickets` breaks a plan into "tracer-bullet vertical slices, each
  declaring the tickets that block it" (`to-tickets/SKILL.md:9`). Each slice cuts "a narrow but
  COMPLETE path through every layer", is "demoable or verifiable on its own" and is "sized to fit in
  a single fresh context window" (`to-tickets/SKILL.md:31-35`). One slice is therefore one issue and,
  under the owner's rule, one PR.
- **Wide refactors** are sequenced as expand, migrate batches, contract, "each batch its own ticket"
  (`to-tickets/SKILL.md:40`). Each of those is also one issue and one PR. The same paragraph allows
  an exception: batches that cannot stay green "share an integration branch that all block a final
  integrate-and-verify ticket". That is the one place the skills contradict one-PR-per-fix and
  default-branch closing keywords (see 2.6).
- **Blocking edges.** On a real tracker, "publish one issue per ticket in dependency order (blockers
  first)", and "use the platform's native blocking / sub-issue relationship where it has one;
  otherwise set each ticket's 'Blocked by'" (`to-tickets/SKILL.md:63`). GitHub has both (sections
  2.5), so the native form applies.
- **Parent.** The issue template has an optional `## Parent` section referencing the source issue
  and a `## Blocked by` section (`to-tickets/SKILL.md:84-103`). "Do NOT close or modify any parent
  issue" (`to-tickets/SKILL.md:67`).
- **`ready-for-agent`.** `to-tickets` applies it to every ticket "unless instructed otherwise; the
  tickets are agent-grabbable by construction" (`to-tickets/SKILL.md:63`). `to-spec` applies it to
  the published spec "no need for additional triage" (`to-spec/SKILL.md:19`).
- **Frontier.** "Work the frontier: any ticket whose blockers are all done" (`to-tickets/SKILL.md:65`).
  `wayfinder` defines it as "the open, unblocked, unclaimed children" of the map
  (`wayfinder/SKILL.md:69`); the GitHub template's query drops children that have an open blocker
  (`issue_dependencies_summary.blocked_by > 0`) or an assignee
  (`setup-matt-pocock-skills/issue-tracker-github.md:43`).

### Triage and agent briefs

- Two category roles (`bug`, `enhancement`) and five state roles; "every triaged issue should carry
  exactly one category role and one state role"; conflicting state roles must be flagged
  (`triage/SKILL.md:26-41`). Role names are canonical and "the actual label strings ... may differ",
  supplied by the mapping file (`triage/SKILL.md:43`).
- Transitions: unlabeled goes to `needs-triage`, then to `needs-info`, `ready-for-agent`,
  `ready-for-human` or `wontfix`; `needs-info` returns to `needs-triage` on reply
  (`triage/SKILL.md:45`). `wontfix` closes the issue; rejected enhancements also write
  `.out-of-scope/` (`triage/SKILL.md:82-85`).
- Moving to `ready-for-agent` posts an agent brief comment (`triage/SKILL.md:79`). The brief is "the
  authoritative specification ... the agent brief is the contract" and is durable: no file paths, no
  line numbers (`triage/AGENT-BRIEF.md:3,9-17`). Template fields: Category, Summary, Current
  behavior, Desired behavior, Key interfaces, Acceptance criteria, Out of scope
  (`triage/AGENT-BRIEF.md:39-68`).
- Every triage comment starts with an AI-generated disclaimer (`triage/SKILL.md:13-17`).
- PRs are in triage only if the tracker config sets "PRs as a request surface" to yes. The setup skill
  defaults it off and says not to raise it (`setup-matt-pocock-skills/SKILL.md:49`;
  `issue-tracker-github.md:18`). Even then discovery covers only external PRs
  (`triage/SKILL.md:64`). The agent PRs this workflow adds are a delivery surface, not a triage
  surface, so the flag stays `no`.

### Chain from issue to PR

- `implement`: use `/tdd` at agreed seams, typecheck and single tests often, full suite once, "use
  /code-review", then "commit your work to the current branch" (`implement/SKILL.md:9-15`). It
  creates no branch, does not push and does not open a PR.
- `code-review`: fixed point supplied by the user, diff is `git diff <fixed-point>...HEAD`
  (`code-review/SKILL.md:21`). The Spec axis finds its source from "issue references in the commit
  messages (`#123`, `Closes #45`, ...)" fetched through `docs/agents/issue-tracker.md`
  (`code-review/SKILL.md:29`). Standards and Spec are reported separately.
- `pr`: only a body template: Summary (diagram/diff/tree), Evidence (before/after), Merge Danger
  (one-way or two-way door, blast radius) (`pr/SKILL.md:12-33,166-170`). It has no issue-link line, so
  `Closes owner/repo#N` must be added.
- `wayfinder` (planning only): the map is an issue labelled `wayfinder:map`; children are sub-issues
  with `wayfinder:<type>` labels; blocking is native; the claim is the assignee, set "first, before
  any work"; research tickets are captured "on a throwaway `research/<name>` branch"
  (`wayfinder/SKILL.md:21,65-69,115`; `issue-tracker-github.md:40-45`). Resolution is a comment plus
  close plus a pointer on the map. Wayfinder tickets are decisions, not code, so they do not need a
  PR; research branches are the only branches it mentions.
- **No skill names a branch pattern or opens a PR.** The only branch strings in the bundle are
  `research/<name>` (wayfinder) and the integration-branch remark (to-tickets).

### Where the skills assume labels for state

Every state transition in `triage`, `to-tickets`, `to-spec` and the `gh issue list --label` queries in
the GitHub template is a label operation (`issue-tracker-github.md:7-12`;
`setup-matt-pocock-skills/triage-labels.md:5-13`). The skills know nothing of Project Status. If a
Status column duplicated the triage roles (a "Triage" column, a "Ready" column), the two would drift:
`triage` would change the label and nobody would update the column, or the reverse. The one clean
split is orthogonal dimensions, described in section 5.

---

## 2. GitHub primary facts

### 2.1 Projects v2 basics

- A project is "an adaptable table, board, and roadmap"; layouts are table, board, roadmap; fields
  can be added beyond built-ins; up to 50 fields per project
  ([About Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)).
- A project holds up to 50,000 items across active views and the archive
  ([Adding items](https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project)).
- Items can come from "any organization" and from several repos by switching the repository dropdown in
  "Add item from repository" (same page). Pasting a URL also adds an item (same page).
- The board layout "is based on the status field by default" and the quickstart's own Todo example is
  an "item added to your project" workflow
  ([Quickstart](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/quickstart-for-projects)).
- A single select field has up to 50 options; one option can be the default for items added later;
  existing items keep their values
  ([Single select fields](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-single-select-fields)).
- Filters: `no:<field>` for missing values, `-` negation, `is:open|closed|merged|issue|pr`,
  `status:`, `type:` (issue type), `label:`, `repo:`, `parent-issue:owner/repo#N`, `assignee:@me`.
  `is:blocked` and `linked-pull-request` are **not documented** and cannot be relied on
  ([Filtering projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/filtering-projects)).
- Parent issue and Sub-issue progress can be shown as project fields and used to group or filter
  ([parent and sub-issue fields](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-parent-issue-and-sub-issue-progress-fields)).
  The Type field appears if the org uses issue types
  ([issue type field](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-the-issue-type-field)).
- Blocked issues "are marked with a 'Blocked' icon on your project boards"
  ([Issue dependencies](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-issue-dependencies)).
- Project fields are scoped to one project; labels are scoped to one repo ("Each label works only in
  the repository where it was created"
  ([Managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels));
  [issue fields](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-fields-in-your-organization)
  says "Project fields are scoped to a single project").

### 2.2 Built-in workflows

- On by default: when an issue or PR in the project is closed its status is set to **Done**; when a PR
  is merged its status is set to **Done**. Example (not default) workflows: set Status to Todo when an
  item is added; close issues when their project status changes. Auto-add and auto-archive are
  separate workflows. Workflows are edited in the project menu under Workflows
  ([Built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)).
  The page does not list "item reopened" or "PR linked" workflows; whether Status returns to a
  non-Done value on reopen is **unverified**.
- **Auto-add**: choose a repository and a filter; filters are `is`, `label`, `reason`, `assignee`,
  `no`; "each workflow targets one repository"; further workflows are made by duplicating, and the same
  repo can have several if filters differ; **limits per plan: Free 1, Pro 5, Team 5, Enterprise
  Cloud 20**; enabling it does **not** add existing matching items
  ([Adding items automatically](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically)).
  Cross-repo coverage therefore needs one workflow per repo. On the Free plan that is one repo.
- **Auto-archive**: filters `is`, `reason`, `updated` (within 14 days, 3 weeks, 1 month); enabling it
  also archives existing matches; archived items keep field data and can be restored
  ([Archiving items automatically](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/archiving-items-automatically)).
  Per-plan limits for archive are not stated there. Exact `updated:` filter syntax for "older than"
  is **unverified**.
- Actions alternative: `actions/add-to-project` exists, but `GITHUB_TOKEN` "cannot access projects";
  org projects want a GitHub App (or a PAT with `project` and `repo`), and a workflow is per repository
  ([Automating projects using Actions](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions)).
  That means secrets in every repo; not recommended here (see Open questions).
- Whether workflows can be created or toggled through an API is **unverified**; the docs show only the
  UI path, and `gh project` has no workflow subcommand.

### 2.3 `gh project`

Subcommands: close, copy, create, delete, edit, field-create, field-delete, field-list, item-add,
item-archive, item-create, item-delete, item-edit, item-list, link, list, mark-template, unlink, view.
There is **no** view-create, workflow, or field-edit command. The minimum scope is `project`
([gh project](https://cli.github.com/manual/gh_project)). Scope check: `gh auth status`; add with
`gh auth refresh -s project` (same page). (Checked live: the token already has `project`.)

- `gh project create --owner <org> --title <t>`
  ([create](https://cli.github.com/manual/gh_project_create)).
- `gh project link [<number>] --owner <org> --repo <repo>` links a project to a repository
  ([link](https://cli.github.com/manual/gh_project_link)). Linking only lists the project on the repo's
  Projects tab; the project must belong to the same owner
  ([Adding your project to a repository](https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-your-project/adding-your-project-to-a-repository)).
  It is not required to add items from that repo (2.1: items come from any repo).
- `gh project field-list <n> --owner <org> [--format json]` lists fields (default `--limit` 30)
  ([field-list](https://cli.github.com/manual/gh_project_field-list)). `field-create` takes
  `--data-type TEXT|SINGLE_SELECT|DATE|NUMBER` and `--single-select-options` (checked in local `--help`).
- `gh project item-add <n> --owner <org> --url <issue-or-pr-url>` adds an item; `--format json --jq .id`
  returns the item id ([item-add](https://cli.github.com/manual/gh_project_item-add)).
- `gh project item-edit` has two modes. By name: project number, `--owner`, `--url`, `--field`,
  `--value` (single-select takes the option name). By id: `--id`, `--field-id`, `--project-id`,
  `--single-select-option-id`. "For non-draft issues, only a single field value can be updated per
  invocation" ([item-edit](https://cli.github.com/manual/gh_project_item-edit)). **The by-name mode
  arrived in gh 2.97.0**
  ([release notes](https://github.com/cli/cli/releases/tag/v2.97.0)); the installed 2.81.0 shows only
  the id mode in `--help` (checked live), where the item id, project id, field id and option id must
  all be fetched first.
- `gh project item-list <n> --owner <org> --query '<filter>' --format json` accepts the Projects filter
  syntax (example from the manual: `label:bug -status:Done`), default `--limit` 30
  ([item-list](https://cli.github.com/manual/gh_project_item-list)). Its JSON shape is **unverified**
  (no Project exists to test against); validate any `--jq` path at setup.
- GraphQL equivalent for id mode: `addProjectV2ItemById` then `updateProjectV2ItemFieldValue`;
  "You cannot add and update an item in the same call"; re-adding an existing item returns the existing
  item id; reads need `read:project`, writes `project`
  ([Using the API to manage Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects)).
- `gh issue create --project <title>` and `gh issue edit --add-project <title>` add an issue by project
  **title** and need the `project` scope (local `--help`, checked live). Neither sets Status.
  `gh pr create --project` exists too, with a PR-adds-to-project note
  ([pr create](https://cli.github.com/manual/gh_pr_create)).

### 2.4 Issue types vs labels

- Issue types are an org-level classification: up to 25 per org; defaults Task, Bug, Feature (editable
  or deletable); usable "when creating filters and views in your projects"
  ([Managing issue types](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-types-in-an-organization)).
  Checked live: viptv-org has exactly Task, Bug, Feature, all enabled.
- `gh issue create --type <name>` and `gh issue edit --type <name>` / `--remove-type` exist
  ([create](https://cli.github.com/manual/gh_issue_create), [edit](https://cli.github.com/manual/gh_issue_edit)),
  added in gh 2.94.0 ([release notes](https://github.com/cli/cli/releases/tag/v2.94.0)).
- Labels are per repo and anyone with write access can create them
  ([Managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels)).
  That is why `needs-triage` and friends must be created repo by repo (they are missing on app, core
  and metadata), whereas a Type change is made once for the org.
- GitHub's docs contain no page that directly compares labels and types; the comparison above is
  inference from the two pages cited.
- **Issue fields** (org-wide single-select, text, number, date, up to 25 per org) are a newer
  alternative to project-scoped fields
  ([Managing issue fields](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/managing-issue-fields-in-your-organization)).
  The page does not mention API or `gh` support; **not recommended** for Status until they are
  scriptable.

### 2.5 Sub-issues and dependencies

- Sub-issues: up to 100 per parent, up to eight levels; parent and sub-issue progress appear in Projects
  ([Adding sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues)).
  REST: `GET/POST /repos/{owner}/{repo}/issues/{n}/sub_issues`, `DELETE .../sub_issue`,
  `GET .../parent`; the body takes `sub_issue_id`, which appears to be the issue's database `id`, not its
  number (the page does not say so explicitly); "The sub-issue must belong to the same repository
  owner as the parent issue", which allows cross-repo within the org
  ([Sub-issues REST](https://docs.github.com/en/rest/issues/sub-issues)).
- Dependencies: `GET/POST /repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by`,
  `DELETE .../blocked_by/{issue_id}`, `GET .../blocking`; `issue_id` is the issue `id` (not the
  number, inferred as above); responses carry `issue_dependencies_summary` with `blocked_by`,
  `blocking`, `total_blocked_by`, `total_blocking`
  ([Issue dependencies REST](https://docs.github.com/en/rest/issues/issue-dependencies)). The docs page
  does not say whether cross-repo dependencies are allowed, whether a blocked issue can be closed, or
  which plans include dependencies (**unverified**; the vendored template already uses this API,
  `issue-tracker-github.md:42`).
- **CLI support exists from gh 2.94.0**: `gh issue create --parent N --blocked-by N,N --blocking N`;
  `gh issue edit --parent / --remove-parent / --add-sub-issue / --remove-sub-issue /
  --add-blocked-by / --remove-blocked-by / --add-blocking / --remove-blocking`; these accept numbers
  or URLs, and `view`/`list` display the relationships
  ([edit](https://cli.github.com/manual/gh_issue_edit),
  [create](https://cli.github.com/manual/gh_issue_create),
  [v2.94.0](https://github.com/cli/cli/releases/tag/v2.94.0)). On the installed 2.81.0 none of these flags
  exist (checked live), so the raw `gh api` calls in the vendored template are the only route there
  and need the numeric database id. Note the `gh issue edit` page lists no flag for Project Status.
- Whether a parent auto-closes when all sub-issues close is not described in the pages read
  (**unverified**; assume it does not).

### 2.6 Closing keywords, branches, Development sidebar

- Keywords: close(s/d), fix(es/ed), resolve(s/d); cross-repo form `KEYWORD OWNER/REPO#N`; each issue
  needs its own full keyword; the PR must target the default branch or "these keywords are ignored, no
  links are created, and merging the PR has no effect on the issues". Manual linking through the
  Development sidebar allows up to ten issues and only within the same repo; an issue can link to a
  branch or PR from another repo
  ([Linking a PR to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue)).
- Branches created for an issue appear in the issue's Development sidebar; once a PR is opened from the
  branch, GitHub links the PR to the issue and removes the branch from that section; the branch name
  field is optional and the docs set no default format
  ([Creating a branch for an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-a-branch-for-an-issue)).
- `gh issue develop <n> --name <branch> --base <branch> [--checkout] [--list]` creates the linked branch
  and `--base` also sets the PR base for `gh pr create`
  ([issue develop](https://cli.github.com/manual/gh_issue_develop); local `--help`). `--worktree <path>`
  (check the branch out into a separate worktree) arrived in gh 2.99.0
  ([release notes](https://github.com/cli/cli/releases/tag/v2.99.0)).
- `gh pr create` puts the closing keyword in the body: "Put `Fixes #123` or `Closes #123` in the PR
  body", default base is the repo's default branch, and `--body-file` is supported
  ([pr create](https://cli.github.com/manual/gh_pr_create)). `gh pr merge` has `--merge`, `--squash`,
  `--rebase`, `--delete-branch`, `--auto`, `--admin`
  ([pr merge](https://cli.github.com/manual/gh_pr_merge)).

---

## 3. Agent-workflow practice (from the docs and skills only)

- **One purpose per PR.** "Small, focused pull requests are easier to review and safer to merge ... splitting
  it into smaller pull requests that each serve one purpose"
  ([Helping others review](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/getting-started/helping-others-review-your-changes)).
  Splitting large issues "leads to smaller pull requests, which are easier to review"
  ([Best practices for Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects)).
  GitHub does not say what to do with an unrelated bug found mid-task; the rule below (open a new issue)
  is the project's inference from "one purpose".
- **Branch per issue.** GitHub prescribes no name; its tooling links by relationship, not by name. A
  name carrying the issue number is a convention that makes `git branch`, `code-review`'s issue lookup
  (`code-review/SKILL.md:29`) and humans work without API calls.
- **Single source of truth.** "To prevent information from getting out of sync, maintain a single source of
  truth" ([Best practices for Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/best-practices-for-projects)),
  and "the less you need to remember to do manually, the more likely your project will stay up to
  date" (same page). Applied here: state changes should come from workflows and relationships
  (closed to Done, PR keyword to closed, blocked-by edge to Blocked icon), and be set by hand only
  where no workflow exists.
- **Labels vs Status.** Labels are per repo and written by whoever has triage access
  ([Managing labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels));
  Status is one org-wide field with workflows attached
  ([Built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)).
  The skills own the labels (section 1). Hence the split in section 5.

---

## 4. Constraints specific to this org

1. **Free plan: one auto-add workflow, one repo each** (2.2, plan checked live). Auto-add cannot be the
   mechanism. Upgrading to Team gives five, still fewer than the repo count.
2. **All agents share one GitHub account** (the `gh` token is Gratenes, checked live). The assignee
   claim in `wayfinder` (`wayfinder/SKILL.md:67`) cannot tell two agent sessions, or an agent and the
   owner, apart. Status `In progress` plus a linked branch is the stronger claim; assignee still records
   ownership.
3. **PRs need a different closing path in integration-branch flows** (2.6). Any issue whose PR targets a
   non-default branch will not auto-close and Status will not move to Done.
4. **Private repos exist** (app, metadata, playback-gateway, checked live). Project item titles for
   those issues are visible to anyone who can see the Project and the repo. Project visibility and
   which of these repos' items appear on a shared board is an owner decision (the pages read do not
   describe private-repo behavior; **unverified**).
5. **Done is not deployed** (`AGENTS.md:86-87`). Do not extend the Done column's meaning.

---

## 5. Recommended workflow (recommendation, not a decision)

### A. The Project

One org Project, suggested title `VIPTV Work`, owned by `viptv-org`, visibility chosen by the owner.
Linked to every active repo with `gh project link` (cosmetic: puts it on each repo's Projects tab).

| Field | Kind | Values | Written by |
|---|---|---|---|
| Status | built-in single select, options edited in the UI | `Backlog` (default for new items), `In progress`, `In review`, `Done` | agents set the first three; built-in workflows set Done |
| Type | built-in issue type field, enabled | Task, Bug, Feature (org types) | agents set at `gh issue create --type` |
| Parent issue, Sub-issue progress | built-in, enabled | | native sub-issue edges |

No other custom fields. In particular **no Blocked, Triage, Ready, or Wontfix Status option** and no
priority field until needed.

| State question | Single owner | Never also stored in |
|---|---|---|
| May an agent start this? Needs info? Needs a human? Rejected? | triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) | Status |
| Where is it in execution? | Status | labels |
| Is it blocked? | native blocked-by edge | Status, labels, body text |
| Is it a bug/feature/task? | Issue type | `bug`/`enhancement` labels |
| Who owns it right now? | assignee | Status |
| Is it finished? | issue state (closed), which drives Status Done | a label |

Views (UI only; the CLI cannot create views):

1. `Board`: board layout grouped by Status, all repos.
2. `Agent frontier`: table, filter `status:Backlog label:ready-for-agent is:open`. Blocked items still
   appear because blocked state is not filterable (2.1); they show the Blocked icon, and agents must
   re-check (section D).
3. `Needs triage`: `is:open label:needs-triage`; and `Needs human`: `is:open label:ready-for-human`.
4. `By parent`: table grouped by Parent issue with Sub-issue progress.

### B. Workflows to enable (web UI, owner, once)

| Workflow | Setting | Why |
|---|---|---|
| Item closed | on (default) | closed issue, including `wontfix` closed as not planned, goes to Done |
| Pull request merged | on (default) | harmless; PRs are not added to the Project (see below) |
| Item added to project | Status = Backlog | safety net for items added by hand or by auto-add; also set the Status default option. The docs name this only as an example workflow, so confirm the UI offers it |
| Auto-add | optional, one repo only | Free plan limit; see Open questions |
| Auto-archive | `is:closed` older than about three weeks | keeps the board small; exact `updated:` syntax **unverified**, test in the UI |
| "Close issue when Status changes" | **leave off** | reverse direction would let a Status drag close an unmerged issue |

PRs are not added to the Project. The issue is the card; the PR is visible in its Development sidebar.
This avoids two cards per fix.

### C. Triage labels vs Status

Keep the five triage labels exactly as `docs/agents/triage-labels.md` has them. They answer "who may act".
Status answers "how far along". Mapping:

| Label | Status while open | Agent action |
|---|---|---|
| `needs-triage` | Backlog | do not start; run `/triage` |
| `needs-info` | Backlog | do not start |
| `ready-for-agent` | Backlog, then In progress, In review | eligible; claim by setting In progress |
| `ready-for-human` | Backlog (a human sets In progress) | do not start |
| `wontfix` | closed as not planned, so Done | none |

Invariants (audit by hand or script): an open issue with Status other than Backlog must carry
`ready-for-agent` or `ready-for-human`; a closed issue must be Done; an open issue with `needs-triage` or
`needs-info` must be Backlog. When an agent starts work it does not remove `ready-for-agent`; Status
carries the claim. Rationale: the skills query by label (`issue-tracker-github.md:9`) and cannot be
changed without forking the bundle; the Project's Status is the one thing no skill touches.

Category: use the org Issue type (Bug, Feature, Task) and stop applying `bug`/`enhancement` labels in new
issues. The triage skill counts them as roles (`triage/SKILL.md:26-41`), so the local mapping file must
say Type satisfies the category role. If the owner prefers zero skill friction, keep the labels and skip
Type; do not keep both.

Alternative considered: a "Triage" single-select project field in place of the labels. It would give one
org-wide vocabulary and remove the need to create labels on app, core and metadata, but every skill and
`gh issue list --label` query would need rewriting and `gh issue list` cannot filter by a project field.
Rejected for now.

### D. Branches, PRs and issue linking

- One issue, one branch, one PR, in the issue's repo. The issue lives in the repo that owns the change, so
  branch, issue and PR share a repo and `Closes` needs no cross-repo form (use it anyway for
  consistency).
- Branch name: `<kind>/<issue#>-<slug>`, `kind` one of `fix`, `feature`, `chore`, `docs`, `research`.
  This extends the existing `app` convention (`fix/<slug>`, `feature/<slug>`) and the wayfinder
  `research/<name>` branches (`wayfinder/SKILL.md:115`). Example: `fix/142-dv-undecodable-autoplay`.
- Unrelated discovery mid-task: do not fix it on this branch. `gh issue create` it (section E), add it to
  the Project as Backlog, finish the current PR. A PR contains only the diff for its issue.
- Parallel agents: one `git worktree` per issue (`gh issue develop --worktree` on gh 2.99+). Never two
  issues on one working tree.
- Tickets from `to-tickets`: each slice is its own issue and PR. Blocked slices start only after the
  blocker's PR has merged, because Done follows merge.
- Integration branches (the `to-tickets` exception, `to-tickets/SKILL.md:40`): disallow unless the owner
  approves case by case, because closing keywords are ignored off the default branch (2.6) and the
  one-PR-per-fix rule breaks.
- PR body: the vendored `pr` template (Summary, Evidence, Merge Danger, `pr/SKILL.md:14-33`) with a final
  line `Closes viptv-org/<repo>#<N>`. One keyword line per issue. PR title is `<imperative summary>`; no
  issue number needed in the title.
- Commit messages reference the issue (`Refs #N`) so `code-review` can find the spec
  (`code-review/SKILL.md:29`). Do not use closing keywords in commits; only the PR
  closes.
- Merge: `gh pr merge --merge --delete-branch` keeps today's `--no-ff` merge-commit history
  (`gh pr merge` page above); the owner may prefer `--squash`. Agents may merge reviewed PRs to main
  (`docs/agents/handoff.md:24-25`); deployment still needs separate approval and a served-hash check
  (`AGENTS.md:86-87`).

### E. Exact commands

Set once per session (project number is whatever `gh project create` reports; no ids needed on gh 2.97+):

```bash
export ORG=viptv-org PROJECT_NUMBER=<n> PROJECT_TITLE="VIPTV Work" REPO=<repo>
gh --version            # must be >= 2.99.0
```

**One-time owner setup** (shown for completeness; this research did not run any of it):

```bash
gh project create --owner "$ORG" --title "$PROJECT_TITLE"
for r in app backend core design metadata playback-gateway web workspace; do   # active repos only
  gh project link "$PROJECT_NUMBER" --owner "$ORG" --repo "$ORG/$r"
done
# Status options, views and workflows are edited in the web UI (no CLI command).
# Missing triage labels, e.g. for app, core, metadata:
gh label create needs-triage -R "$ORG/app"   # repeat for the five labels and each repo
# Backfill existing open issues (auto-add never backfills):
gh issue list -R "$ORG/$REPO" --state open --limit 200 --json url --jq '.[].url' |
  while read -r u; do gh project item-add "$PROJECT_NUMBER" --owner "$ORG" --url "$u"; done
```

**Create** (`to-tickets`, `to-spec`, `triage`, any agent that files work; chain parents and blockers
here, in blocker-first order):

```bash
url=$(gh issue create -R "$ORG/$REPO" --title "<title>" --body-file brief.md \
        --type Bug --label needs-triage \
        --project "$PROJECT_TITLE" [--parent <n|url>] [--blocked-by <n|url>,...])
gh project item-edit "$PROJECT_NUMBER" --owner "$ORG" --url "$url" --field Status --value Backlog
```

`to-tickets` and `to-spec` use `--label ready-for-agent` instead of `needs-triage`, per their skills.
`brief.md` follows `triage/AGENT-BRIEF.md` for `ready-for-agent` issues.

**Pick up** (frontier):

```bash
# 1. candidates: open, Backlog, ready-for-agent, any repo
gh project item-list "$PROJECT_NUMBER" --owner "$ORG" --limit 100 \
  --query 'status:Backlog label:ready-for-agent is:open'
# 2. for the chosen issue: refuse if blocked or already claimed
gh api "repos/$ORG/$REPO/issues/$N" --jq '.issue_dependencies_summary.blocked_by'   # must be 0
gh issue develop --list "$N" -R "$ORG/$REPO"                                       # must be empty
gh issue view "$N" -R "$ORG/$REPO" --comments                                      # read brief
```

**Start**:

```bash
gh issue develop "$N" -R "$ORG/$REPO" --name "fix/$N-<slug>" --base main --checkout
# or, for a parallel agent:
gh issue develop "$N" -R "$ORG/$REPO" --name "fix/$N-<slug>" --base main \
  --checkout --worktree "../wt-$REPO-$N"
gh issue edit "$N" -R "$ORG/$REPO" --add-assignee @me
gh project item-edit "$PROJECT_NUMBER" --owner "$ORG" \
  --url "https://github.com/$ORG/$REPO/issues/$N" --field Status --value "In progress"
```

Check order matters: the claim is not atomic, so check blockers and linked branches first, then claim at once.

**Work**: `/implement` (with `/tdd`, repo checks from `AGENTS.md`), commit with `Refs #N`, then
`/code-review` against `origin/main`.

**Finish** (open the PR):

```bash
git push -u origin "fix/$N-<slug>"
gh pr create -R "$ORG/$REPO" --base main --head "fix/$N-<slug>" \
  --title "<imperative summary>" --body-file pr-body.md   # pr skill template + Closes line
gh project item-edit "$PROJECT_NUMBER" --owner "$ORG" \
  --url "https://github.com/$ORG/$REPO/issues/$N" --field Status --value "In review"
```

The last line of `pr-body.md` is `Closes viptv-org/<repo>#<N>`.

**Merge and verify**:

```bash
gh pr merge <pr> -R "$ORG/$REPO" --merge --delete-branch
gh issue view "$N" -R "$ORG/$REPO" --json state,stateReason      # must be CLOSED
gh project item-list "$PROJECT_NUMBER" --owner "$ORG" --query "repo:$ORG/$REPO status:Done" \
  | grep -q "$N" || gh project item-edit "$PROJECT_NUMBER" --owner "$ORG" \
       --url "https://github.com/$ORG/$REPO/issues/$N" --field Status --value Done
```

Do not close the issue by hand; the keyword does. If the issue is reopened, set Status back to Backlog
(no reopen workflow is documented).

---

## 6. Changes needed

### `docs/agents/issue-tracker.md` (describe only; not edited)

- Add a **Project** section: the Project title and number, that every new issue is added with
  `--project`, that PRs are not added, and that Status is Backlog / In progress / In review / Done.
- Replace the single-line command list with the section E commands, and require gh >= 2.99.
- State the **ownership table** from 5.A (labels = triage role, Status = stage, edge = blocked, type =
  category).
- Add the **Branch and PR** section: `<kind>/<issue#>-<slug>`, one issue per branch, `gh issue develop`,
  worktree for parallel work, PR template plus `Closes viptv-org/<repo>#N`, merge command, and "Done =
  merged, not deployed".
- Clarify "PRs as a request surface: no" as "external PRs are not a triage queue; agent PRs are the
  delivery surface for issues". Keep the flag value `no`.
- Add the **Wayfinding operations** section from the template
  (`issue-tracker-github.md:36-45`), rewritten to use `gh issue create --parent` / `--blocked-by` on
  gh >= 2.94 instead of the raw `gh api` calls, and noting the shared-account caveat for the assignee
  claim (4.2).
- Under "when a skill says publish to the issue tracker": create the issue, set Type, add to the Project,
  wire parent and blocked-by edges, set Status Backlog.

### `docs/agents/triage-labels.md`

- Keep the identity mapping. Add the label/Status table and invariants from 5.C.
- Add that moving to `ready-for-agent` does not change Status, and starting work changes Status only.
- Add that `bug`/`enhancement` are satisfied by Issue type Bug/Feature (if the owner picks that), and
  note `needs-triage` etc. must exist on every repo (create on app, core, metadata).

### Skills (`to-tickets`, `triage`, others)

No edit is strictly required, because each skill defers to `docs/agents/*`
(`to-tickets/SKILL.md:11`, `triage/SKILL.md:43`, `code-review/SKILL.md:13`). Optional upstream-diverging
edits, listed in order of value; each would need re-doing after a bundle update (the install script is
additive and leaves existing folders alone, `docs/agents/handoff.md`, Skill bundle section):

1. `to-tickets`: step 5 should say "set Status Backlog" and add the parent/blocked edges through the
   tracker doc rather than by prose; it already defers.
2. `implement`: add "create the branch with `gh issue develop` before the first commit" and "push and open
   a PR with `/pr`" (currently stops at "Commit your work to the current branch").
3. `pr`: add a closing-keyword line to the template.
4. `triage`: category roles read as Issue types where the tracker doc says so.

Prefer putting these four rules in `AGENTS.md` / `docs/agents/issue-tracker.md` (project-level, survive
updates) and leaving the vendored skills untouched.

---

## Open questions for the owner

1. **Auto-add**: spend the single Free-plan workflow on one repo (which: `app`, where humans file most
   issues?), or none and rely on agents plus a periodic audit? Upgrading to Team gives five, still short.
2. **Status vocabulary**: is `Backlog / In progress / In review / Done` right? Do you want a `Blocked`
   column despite the double-entry risk?
3. **Category**: switch to Issue type and drop `bug`/`enhancement` labels, or keep labels?
4. **Merge strategy**: `--merge` (matches today's `--no-ff`) or `--squash`?
5. **Integration branches**: forbid, or allow with manual Done and manual closing?
6. **PRs on the board**: keep PRs off the Project (recommended), or add them and accept two cards per fix?
7. **Wayfinder maps**: add the `wayfinder:map` issue to the board, or hide it? Maps are containers and
   would sit in Backlog forever.
8. **Project visibility** and whether private repos' issues appear on the same board.
9. **Shared account**: acceptable that every agent claims as the same user (4.2)? A second bot account
   would make assignee claims meaningful.
10. **Reopen**: no documented workflow sets Status after reopen. Accept a manual rule, or test whether the
    UI offers a reopen workflow when you set up the Project?
11. **Merge authority**: `handoff.md:24-25` lets agents merge reviewed PRs. Keep that, or have agents stop
    at "In review" for the owner to merge?
12. **Actions-based auto-add**: acceptable to store a GitHub App or PAT secret in every repo to bypass the
    Free-plan limit? (Recommended no.)

## Sources

Local files (read 2026-10-22): `AGENTS.md`; `docs/agents/issue-tracker.md`, `triage-labels.md`,
`handoff.md`; `.agents/skills/` `to-tickets`, `triage` (`SKILL.md`, `AGENT-BRIEF.md`, `OUT-OF-SCOPE.md`),
`setup-matt-pocock-skills` (`SKILL.md`, `issue-tracker-github.md`, `triage-labels.md`), `to-spec`,
`implement`, `pr`, `wayfinder`, `code-review`.

GitHub documentation and CLI manual pages are linked inline. GitHub CLI release notes read:
[v2.94.0](https://github.com/cli/cli/releases/tag/v2.94.0),
[v2.97.0](https://github.com/cli/cli/releases/tag/v2.97.0),
[v2.99.0](https://github.com/cli/cli/releases/tag/v2.99.0).

Not verified from a primary source: Projects workflows via API; `item-list` JSON shape; behavior of Status
on reopen; whether blocked issues can be closed and plan availability of dependencies; private-repo item
visibility in Projects; exact `updated:` filter syntax for auto-archive; whether `Closes` is needed when a
PR is linked through `gh issue develop` (kept for safety).
