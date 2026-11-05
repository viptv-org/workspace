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
| Python 3.9+ | `design` validation, `backend` and `app` native build scripts |

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
- `app` desktop builds need JDK 21 (`openjdk-21-jdk`), `python3` (every native
  runtime task runs a `tools/*.py` script) and these host packages:

  ```sh
  sudo apt-get install -y libdbus-1-dev libmpv2 mpv patchelf libgl1
  ```

  - `libdbus-1-dev`: the pkg-config entry for `dbus-1` that `libdbus-sys`, built
    through `dbus-secret-service` by `:composeApp:buildDesktopEngine`, looks for.
    The `libdbus-1-3` runtime alone fails with `Package 'dbus-1', required by
    'virtual:world', not found`.
  - `libmpv2` + `mpv` + `patchelf`: `tools/build_mpv.py` bundles the installed
    libmpv with its private dependency closure for
    `:composeApp:buildDesktopMpv`. It records `mpv --version`, so the library
    without the CLI fails, and it rewrites the bundled rpaths with `patchelf`.
  - `libgl1`: Skiko's `libskiko-linux-x64.so` links `libGL.so.1`, so without it
    `:composeApp:desktopTest` dies loading the library in any `ImageComposeScene`
    test, before a GL context is ever opened.
  - Go 1.25: `:composeApp:buildDesktopTorrent` builds the pinned
    `torrent-runtime`, whose `go.mod` declares `go 1.25.0`, with
    `GOTOOLCHAIN=go1.25.11`. Any `go` on `PATH`, or `GO`, builds it when it can
    fetch that toolchain. `tools/build_torrent_runtime.py` (Android) pins the
    same toolchain and needs the NDK.

  Android builds use Rust `1.98` with the `aarch64-linux-android`,
  `armv7-linux-androideabi` and `x86_64-linux-android` targets; desktop builds
  use `1.98.0`.

### When a host lacks the desktop packages

Desktop tests still run on such a host with two adjustments.

The engine build (`libdbus-sys`) needs a pkg-config entry for `dbus-1`. If a
user-local shim stands in for `libdbus-1-dev`, point pkg-config at it:

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
locally, so a local failure in those classes on such a host is not a
regression. A host without `libGL.so.1` accepts a stub library on
`LD_LIBRARY_PATH` for the tests that never open a GL context.

`app/.github/workflows/app-checks.yml` is the authority for the desktop suite:
its `native-prep` job installs `libdbus-1-dev` and Go `1.25.11`, and its
`desktop-test` job installs `libmpv2`, `mpv` and `patchelf` and runs against the
natives `native-prep` uploads. The runner image supplies `libGL.so.1`.

## What each repository needs

| Repo | Toolchain |
|---|---|
| `app` | JDK 21; Rust `1.98.0` (desktop) and `1.98` (Android targets); Android SDK + NDK; Go 1.25; `libdbus-1-dev` + `libmpv2` + `mpv` + `patchelf` + `libgl1` for desktop |
| `backend` | Rust (cargo); Docker only for packaging/preflight |
| `core` | Rust + `wasm32-unknown-unknown` + wasm-bindgen CLI for bindings; Node for `packages/` |
| `design` | python3 |
| `playback-gateway` | Rust (cargo) |
| `workspace` | bash; git |

The scripts were developed and verified on Linux. The Windows path (Git
Bash) is designed to work — plain bash, no GNU-only flags — but has not been
executed on a Windows machine yet.
