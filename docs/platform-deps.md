# Platform dependencies

What each operating system needs to work across the VIPTV repositories.
`./setup.sh`, `./update.sh`, and `./run.sh` are plain bash and run on Linux,
macOS, and Git Bash (Git for Windows). On Windows use Git Bash or WSL2 — do
not drive them from cmd/PowerShell.

## Common (all repositories)

| Tool | Why |
|---|---|
| Git 2.30+ | every repository |
| bash | the scripts in this repo (Git Bash ships with Git for Windows) |
| Node.js LTS (20+) | `web`, `tv-web`, `video`, `tauri-video-plugin`, `core` packages |
| Rust (stable, via rustup) | `backend`, `core`, `tauri-video-plugin` |
| Python 3.8+ | `design` validation, `backend` helper scripts, `roku` packaging |

## Windows

- Git for Windows (provides Git Bash) — or WSL2 with the Ubuntu setup below.
- Rust: rustup with the `x86_64-pc-windows-msvc` toolchain; this needs the
  Visual Studio Build Tools C++ workload.
- Node.js LTS from nodejs.org or nvm-windows.
- Android work (`android`): JDK 17, Android SDK (Platform 36), NDK 27.2 +
  cargo-ndk for `android`'s
  core native libraries.
- `tauri-video-plugin` Rust tests need a native media runtime available to
  the host (for example GStreamer binaries on PATH).
- Recommended: `git config --global core.autocrlf false` (or `input`) so
  checkouts match Linux byte-for-byte.

## Linux (Debian/Ubuntu)

```sh
sudo apt-get update
sudo apt-get install -y build-essential curl git python3
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Node LTS via nvm or NodeSource
```

- Rust extra targets: `rustup target add wasm32-unknown-unknown` for `core`
  bindings; Android targets plus cargo-ndk 4.1.2 and NDK 27.2 for `android`.
- Android work: JDK 17 (`openjdk-17-jdk`), Android cmdline-tools with SDK
  Platform 35/36.
- `tauri-video-plugin` native media tests: install GStreamer dev/runtime
  packages (for example `libgstreamer1.0-dev gstreamer1.0-plugins-base`).

## What each repository needs

| Repo | Toolchain |
|---|---|
| `design` | python3 |
| `backend` | Rust (cargo); Docker only for packaging/preflight |
| `web` | Node |
| `tv-web` | Node; Chromium for Playwright e2e |
| `core` | Rust + `wasm32-unknown-unknown` + wasm-bindgen CLI for bindings; Node for `packages/` |
| `video` | Node 20+ |
| `tauri-video-plugin` | Node 20+, Rust, host media runtime (GStreamer on Linux) |
| `android` | JDK 17, Android SDK Platform 36, NDK 27.2, cargo-ndk, Rust Android targets, Node (core sync) |
| `roku` | git + python3 (packaging); BrighterScript staging runs in CI |
| `.github` | nothing (organization profile) |

The scripts were developed and verified on Linux. The Windows path (Git
Bash) is designed to work — plain bash, no GNU-only flags — but has not been
executed on a Windows machine yet.
