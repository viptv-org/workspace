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
| Node.js LTS (20+) | `core` packages |
| Rust (stable, via rustup) | `backend`, `core`, `playback-gateway` |
| Python 3.8+ | `design` validation, `backend` helper scripts |

## Windows

- Git for Windows (provides Git Bash) — or WSL2 with the Ubuntu setup below.
- Rust: rustup with the `x86_64-pc-windows-msvc` toolchain; this needs the
  Visual Studio Build Tools C++ workload.
- Node.js LTS from nodejs.org or nvm-windows.
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
  bindings; Android targets plus cargo-ndk 4.1.2 and NDK 27.2 for `app`.
- `app` Android work: JDK 21 (`openjdk-21-jdk`), Android cmdline-tools with SDK
  Platform 35/36.
- `app` desktop builds assemble a native mpv runtime from the installed
  library and CLI (`sudo apt-get install -y libmpv2 patchelf mpv`), and need
  JDK 21 (`openjdk-21-jdk`). Android builds use Rust `1.98` with the
  `aarch64-linux-android`, `armv7-linux-androideabi` and `x86_64-linux-android`
  targets; desktop builds use `1.98.0`.

### When the desktop runtime packages are absent

Some Linux hosts have the `libdbus-1` runtime but not `libdbus-1-dev`, and no
`libmpv2`/`patchelf`/`mpv`. Desktop tests still run there with two adjustments.

The engine build (`libdbus-sys`) needs a pkg-config entry for `dbus-1`. If a
user-local shim exists at `~/.local/pkgconfig/dbus-1.pc`, point pkg-config at
it:

```sh
PKG_CONFIG_PATH=$HOME/.local/pkgconfig ./gradlew --max-workers=1 :composeApp:desktopTest
```

Without the mpv packages, drop the two native-runtime tasks so the graph reaches
the tests:

```sh
PKG_CONFIG_PATH=$HOME/.local/pkgconfig ./gradlew --max-workers=1 :composeApp:desktopTest \
  -x :composeApp:buildDesktopMpv -x :composeApp:buildDesktopTorrent
```

The mpv-backed tests (`MpvNativeTest`, `MpvGlNativeTest`) then do not run
locally. `app/.github/workflows/app-checks.yml` installs `libdbus-1-dev`,
`libmpv-dev`, `mpv` and `patchelf` and is the authority for the desktop suite,
so a local failure in those classes on such a host is not a regression.

## What each repository needs

| Repo | Toolchain |
|---|---|
| `app` | JDK 21; Rust `1.98.0` (desktop) and `1.98` (Android targets); Android SDK + NDK; `libmpv2` + `patchelf` + `mpv` for desktop |
| `backend` | Rust (cargo); Docker only for packaging/preflight |
| `core` | Rust + `wasm32-unknown-unknown` + wasm-bindgen CLI for bindings; Node for `packages/` |
| `design` | python3 |
| `playback-gateway` | Rust (cargo) |
| `workspace` | bash; git |

The scripts were developed and verified on Linux. The Windows path (Git
Bash) is designed to work — plain bash, no GNU-only flags — but has not been
executed on a Windows machine yet.
