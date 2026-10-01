# VIPTV workspace

Clone-first bootstrap and coordination repository for the VIPTV organization.
It holds no product code; every product change happens in its owning repository.

## Owns

- **Bootstrap:** `setup.sh` clones every organization repository into the
  canonical layout, `update.sh` fast-forwards them and `run.sh` wraps each
  repository's documented checks. Scripts are portable bash (Linux, macOS,
  Git Bash). Repositories that need extra access (`playback-gateway`) are
  optional: a missing clone is a warning, never a failure.
- **Portable skills:** the vendored `.agents/skills` bundle and
  `skills-lock.json` (source, path and folder hash per skill), installed
  additively by `scripts/install-agent-skills.sh` without overwriting existing
  skills, lockfiles, configuration or AGENTS files.
- **Agent guidance:** `AGENTS.md`, `docs/agents/` (issue tracker, triage labels,
  domain docs, handoff pointer) and `docs/platform-deps.md`.
- **Handoff coordination:** the integration handoff map
  ([issue 2](https://github.com/viptv-org/workspace/issues/2)) is the live
  record of branch tips, owning tickets and remaining gates.
- **Organization metadata:** `meta/github/` holds the spec and design pin for
  the public `.github` profile repository.

## Does not own

Product behavior (design), application code, deployment material, credentials
or private tooling. `.env`, `.local-https/` and deployment notes stay ignored
and untracked.

## Acceptance

- `bash -n` passes for every script; `./setup.sh` in a fresh clone produces the
  canonical layout, installs missing skills and exits 0 when only optional
  repositories are unavailable.
- Every vendored skill has a lock entry whose `computedHash` matches its folder.
- Docs contain no secrets, private hostnames, addresses or credentials.
- Handoff state is kept in issue 2 and the design implementation ledger, not
  duplicated in tracked files.
