# /work brief: app (KMP) notes

Read after `work-brief.md` for issues in `viptv-org/app`.

## Worktree and toolchain

- `scripts/agents/claim.sh` already copies `local.properties` and
  initialises the `native/core` submodule. If `prepareKitePlayer` fails,
  copy `build/kiteplayer/maven` from the main `app` clone.
- Gradle needs `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` (the default
  java has no javac).
- `RUSTUP_TOOLCHAIN=1.98.0` works for desktop builds. Android builds need
  `RUSTUP_TOOLCHAIN=1.98`, which has the Android targets.
- Desktop builds in a worktree need
  `VIPTV_PLAYBACK_GATEWAY=<workspace>/playback-gateway` (app#19).
- Run desktop tests with `LC_ALL=C` (`MpvNativeTest` fails under other
  locales).
- Known flaky test: the Compose "LayoutNode not found in RectList" error
  (app#16, app#27). Rerun that class alone.
- The first `desktopTest` in a fresh worktree builds the Rust engine
  (about 7 minutes).

## Checks

- `:composeApp:desktopTest`, the main gate.
- `:composeApp:compileAndroidMain` and `:composeApp:compileKotlinWasmJs`, **always**. `commonMain` code also compiles for Android and the web, and the desktop tests don't catch platform-only APIs (app#88: a desktop-only `DialogProperties` argument broke Android).
- `:composeApp:testAndroidHostTest`, the Robolectric Android tests, when
  you touch `androidMain`.
- `:androidApp:assembleDebug`, only when you change `androidApp/` or
  `androidMain`.
- `-Pviptv.abis=x86_64` for iteration APKs (`docs/ANDROID_BUILD.md`).

## Verification override

Most app issues carry a "Verification (updated 2026-10-26)" section: no
APK and no emulator. Prove the change with desktop tests, plus desktop or
web screenshots (`:composeApp:run`, or the web build driven with the
playwright-cli skill against a fake or preview server, never the owner's
account). The orchestrator installs green batches on the TV emulator.
