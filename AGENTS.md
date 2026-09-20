# VIPTV organization workspace

This repository **is** the working directory for the whole VIPTV organization.
Clone it, run `./setup.sh`, and every org repository appears in this repo's
root in the canonical layout. The tracked files of this repo (AGENTS.md,
README.md, CONTRIBUTING.md, docs/, setup.sh, update.sh, run.sh) are the
workspace notes: `./update.sh` fast-forwards the notes together with every
clone. Cloned repositories are git-ignored here — each subdirectory is its
own repository. Commit and push inside the owning repo.

| Repo | Owns |
|---|---|
| `design` | Product specs, assets, interaction contract; start here for UX |
| `backend` | Rust API, auth, catalog/media services, deployment packaging |
| `web` | Account and admin web app (also the `backend` `dashboard` submodule) |
| `tv-web` | Shared React viewing client for web, Smart TVs (Tizen/Vizio), and desktop |
| `desktop` | Native Tauri v2 desktop client for Linux, Windows, macOS |
| `core` | Shared Crux Rust state, normalization, generated bindings |
| `video` | React/web/Tizen/Vizio video controller |
| `tauri-video-plugin` | Tauri native playback adapter |
| `android` | Android/Android TV app and playback integration |
| `mediamp` | Android Media3 Compose playback library |
| `roku` | Native Roku client |
| `.github` | Organization profile and shared GitHub metadata |

## Start here

1. `./setup.sh` on first use to clone all repositories into this root.
2. Read the target repo's `AGENTS.md` and README. Product behavior starts in
   `design`; read its pinned `DESIGN_REF` before implementing anything.
3. Make the change in the **owning** repo. Update consumers only when the
   contract changes.
4. Run the repo's documented checks (`./run.sh <repo>` wraps them), then
   commit and push its branch.

## Per-repo check commands

| Repo | Checks |
|---|---|
| `design` | `python3 scripts/validate.py` |
| `backend` | `cargo test --manifest-path server/Cargo.toml`; `scripts/host-check.sh` is the read-only deployment preflight |
| `web` | `npm run build && npm run test` (build = `tsc -b` + `vite build`) |
| `tv-web` | `npm run typecheck && npm run test`; full validation adds `npm run build` (design/core pin checks + vite) and Playwright `npm run test:e2e` |
| `desktop` | `cargo test --manifest-path src-tauri/Cargo.toml`; verify `npm run check` and desktop window launch |
| `core` | `cargo test`; regenerate bindings with `cargo run -p viptv-typegen`, `scripts/build-native-bindings.sh`, `scripts/build-wasm.sh` |
| `video` | `npm run check` (typecheck, effect diagnostics, tests) |
| `tauri-video-plugin` | `npm run check` and `cargo test` (Rust tests need a host media runtime, e.g. GStreamer on Linux) |
| `android` | provisioned machine only: `bash scripts/prepare-core.sh && ./gradlew test` (JDK 17, SDK Platform 36, Rust Android targets, cargo-ndk); hosted CI builds otherwise — keep local Gradle off the memory-constrained shared server |
| `mediamp` | `./gradlew :mediamp-api:compileAndroidMain :mediamp-exoplayer:compileAndroidMain :mediamp-api:assembleUnitTest :mediamp-exoplayer:assembleUnitTest :mediamp-test:assembleUnitTest` (JDK 17, SDK Platform 35) |
| `roku` | no local automated check; CI stages BrighterScript and runs `scripts/package.py` on the staging tree; device testing is coordinated with the owner |
| `.github` | organization profile only |

Machine-specific constraints live in each repo's own AGENTS.md — for example
tv-web bounds Node heap size and worker count on the shared server, and
android/mediamp prefer hosted Gradle builds. Read the repo's file before
running heavy checks there.

## Local testing

Use the local HTTPS environment, not plain HTTP — the viewing client requires
HTTPS and the backend pins a single browser origin (`VIPTV_AUTH_ORIGIN`), so
plain-HTTP testing is not representative:

```sh
./.local-https/up.sh setup && ./.local-https/up.sh start
./.local-https/up.sh stop
```

`.local-https/` is private, untracked tooling maintained by the owner: trusted
loopback TLS, the real backend, and the built front-ends. It is git-ignored
here and never committed because it contains certificates; ask the owner for
access rather than recreating it.

## Deployment

Deployments go through Dokploy. **Every VIPTV Dokploy deploy so far failed
while being reported as successful**, so never claim a change is live without
checking. The proof is the served asset hash:

```sh
curl -sS https://viptv.syek.tech/ | grep -o 'assets/index-[A-Za-z0-9_-]*\.js'
```

Deployment credentials, runbooks, and production topology are private and
live outside git (this repo ignores those paths by design). Read the private
deployment notes before any deploy and get access from the owner. Never run
`docker compose down -v` against production; it deletes the database volume.

## Secrets and device access

Never commit secrets into any tracked file: no passwords, API keys, tokens,
private addresses, certificates, `.env` contents, or provider URLs. Root
`.env` files are private developer environments for local scripts and device
testing; repo `.env.example` files are templates only. Device values (Roku,
Android, ADB) belong in the ignored root `.env`, never in docs, specs,
commits, or issues.

Android emulator values (`ANDROID_SDK_ROOT`, `ANDROID_PHONE_AVD`,
`ANDROID_TV_AVD`) come from the ignored root `.env`. Use emulators for normal
Android and Android TV work; do not configure wireless debugging unless a
real-device test is explicitly requested. Roku device tooling is
owner-maintained; coordinate with the owner for device runs.

## Environment quirks

- The owner's interactive shell is **fish**: no heredocs, and `$?` is
  `$status`. Write helper scripts to a file and run them with `bash`.
- Shell output capture through the owner's editor terminal is unreliable.
  Redirect noisy command output to a temp file and read the file back.
- Docker requires `sudo` on the owner's host; passwordless sudo is available.
- Repos may be checked out through a symlinked path; use one path form
  consistently within a session.
- Scripts in this repo are plain bash and safe under Git Bash on Windows;
  prefer Git Bash or WSL2 over cmd/PowerShell.
