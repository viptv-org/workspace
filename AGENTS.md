# VIPTV organization workspace

This repository is the working directory for the VIPTV organization. `./setup.sh`
clones every org repository into this root; `./update.sh` fast-forwards them and
these notes. Each subdirectory is its own git repository: commit and push inside
the repo that owns the change. This repo's own files (AGENTS.md, docs/, scripts/,
setup.sh, update.sh, run.sh) are the shared notes and tooling.

## Repositories

| Repo | Owns |
|---|---|
| `app` | The only client: Kotlin Compose Multiplatform for Android, Android TV, desktop and web |
| `backend` | Rust API, auth, catalog, continuation, image proxy; serves the web app |
| `core` | Shared Rust engine and its generated wire types; vendored into `backend`, a submodule of `app` |
| `design` | Product specs, copy and the design system; read it before changing UX |
| `playback-gateway` | Ingestion, output jobs and viewer leases |
| `workspace` | This repo: setup, agent tooling, these notes |

`tv-web`, `web`, `desktop`, `video`, `tauri-video-plugin`, `android` and `roku`
are archived clients: don't change them or keep their docs in sync.

## Checks

`./run.sh <repo>` wraps these. Under `/work` they run in the batch gate, not per PR.

| Repo | Checks |
|---|---|
| `app` | `./gradlew :composeApp:desktopTest :composeApp:compileAndroidMain :composeApp:compileKotlinWasmJs` (`--max-workers=1`) |
| `backend` | `cargo test --manifest-path server/Cargo.toml` and `cargo test --manifest-path server/Cargo.toml --features live-runtime --no-run`; `python3 scripts/sync-engine.py check` |
| `core` | `cargo test --workspace --all-features`; regenerate bindings with `cargo run -p viptv-typegen` |
| `design` | `python3 scripts/validate.py` |
| `playback-gateway` | `cargo test --locked --workspace` |

Heavy builds go through `scripts/agents/heavy.sh`, which shares three build slots
across every agent on this machine. Each repo's own AGENTS.md has its toolchain
and test gotchas.

## Issues and /work

Every change is a GitHub issue in the owning repo: one issue, one branch, one PR.
`docs/agents/issue-tracker.md` is the lifecycle and `docs/agents/triage-labels.md`
the labels. A bug found outside the current task becomes a new `bug` +
`needs-triage` issue, never a fix on the current branch.

`/work` (`.agents/skills/work/SKILL.md`) runs the queue. In `app` and `backend`,
PRs merge unbuilt into `edge`; the batch gate tests `edge` and promotes green
commits to `main`, so `main` always builds. Subagents read
`docs/agents/work-brief.md`.

## Comments and docs

- No comments by default. Names and structure carry the meaning.
- The one exception: a trap a reader can't see and would break, in one line
  (for example "Coil must be configured before the first image load").
- Never explain, justify or narrate code, and never write history: no issue or
  PR numbers, dates, owner quotes, or "used to / instead of / changed from /
  now". That belongs in commit messages and PRs.
- Docs describe current behaviour and how to work with it, in as few words as
  will do. Delete a doc instead of letting it go stale.
- Screenshots and renders go in the PR body, not in the repository.

## Safety

- Never commit secrets: passwords, keys, tokens, private hosts, certificates,
  `.env` contents or provider URLs. Device values live in the ignored root `.env`.
- Deploys go through Dokploy and are owner-approved. Dokploy has reported failed
  deploys as successful, so prove a deploy by the asset hash the production
  origin serves (address in the private deployment notes). Never run
  `docker compose down -v` against production: it deletes the database.
- Local testing uses the private HTTPS environment (`./.local-https/up.sh setup`,
  `start`, `stop`); plain HTTP isn't representative. Ask the owner for access.
- Emulators: read the ignored `.local-device-testing.md` first, pass an explicit
  ADB serial, and never uninstall the app, clear its data or sign out. Physical
  TVs only on explicit request.

## Environment

- The owner's shell is fish: write helper scripts to a file and run them with
  bash. Redirect noisy output to a file and read it back.
- Docker needs `sudo` (passwordless).
- Scripts here are plain bash; on Windows use Git Bash or WSL2.
