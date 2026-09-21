# VIPTV workspace

One clone gives you the whole organization. This repository bootstraps the
VIPTV multi-repo working directory: `./setup.sh` clones every org repository
into this repo's root, `./update.sh` fast-forwards all of them, and `./run.sh`
wraps each repository's check commands.

## Quickstart

1. Install the prerequisites (git, bash, Node LTS, Rust, Python 3 — plus
   JDK 17 and the Android SDK only if you touch `android`):
   [docs/platform-deps.md](docs/platform-deps.md).
2. Clone and set up:

   ```sh
   git clone https://github.com/viptv-org/workspace.git
   cd workspace
   ./setup.sh
   ```

   On Windows, run the scripts from Git Bash (Git for Windows) or inside
   WSL2 — not cmd/PowerShell.
3. Run a repository's checks:

   ```sh
   ./run.sh list       # what each repository runs
   ./run.sh tv-web     # one repository
   ./run.sh all        # everything, reporting failures per target
   ```
4. Work inside the owning repository (see the map in
   [AGENTS.md](AGENTS.md)), then commit and push there. Cloned directories
   are ignored by this repo's git.

## Keeping up to date

```sh
./update.sh
```

Fast-forwards this repository (the notes) and every clone. A repository with
uncommitted changes or a diverged branch is reported, never reverted.

## Layout

| Repo | Owns |
|---|---|
| `design` | Product specs, assets, interaction contract; start here for UX |
| `backend` | Rust API, auth, catalog/media services, deployment packaging |
| `web` | Account and admin web app |
| `tv-web` | Shared React viewing client for web, Smart TVs (Tizen/Vizio), and desktop |
| `desktop` | Native Tauri v2 desktop client for Linux, Windows, macOS |
| `core` | Shared Crux Rust state, normalization, generated bindings |
| `video` | React/web/Tizen/Vizio video controller |
| `tauri-video-plugin` | Tauri native playback adapter |
| `android` | Android/Android TV app and playback integration |
| `mediamp` | Android Media3 Compose playback library |
| `roku` | Native Roku client |
| `.github` | Organization profile and shared GitHub metadata |

## Notes

- Product behavior starts in `design` — read its pinned `DESIGN_REF` before
  changing anything users see.
- Never commit secrets. `.env`, certificates, and deployment material are
  git-ignored here and belong to the owner's private environment.
- Deployment caveat: past deploys reported success while actually failing;
  verify the served asset hash before believing anything is live (see
  [AGENTS.md](AGENTS.md)).
- Contributing flow and per-repo guides: [CONTRIBUTING.md](CONTRIBUTING.md).
