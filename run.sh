#!/usr/bin/env bash
# VIPTV workspace task runner: wraps each repository's documented check
# commands. Machine-specific constraints (heap sizes, worker counts, hosted
# builds) are documented in each repository's own AGENTS.md.
#
# Usage:
#   ./run.sh list        show available targets
#   ./run.sh <target>    run one repository's checks
#   ./run.sh all         run every repository's checks
#
# Written for bash on Linux, macOS, and Git Bash (Git for Windows).
set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ -d "$SCRIPT_DIR/../design" ] && [ ! -d "$SCRIPT_DIR/design" ]; then
    cd "$SCRIPT_DIR/.."
else
    cd "$SCRIPT_DIR"
fi

# Run a command inside one of the cloned repositories.
in_repo() {
    repo=$1
    shift
    printf '==> [%s] %s\n' "$repo" "$*"
    ( cd "$repo" && "$@" )
}

# Install npm dependencies the first time a Node repository is checked.
npm_install_if_needed() {
    dir=$1
    if [ ! -d "$dir/node_modules" ]; then
        printf '==> [%s] npm ci (node_modules missing)\n' "$dir"
        ( cd "$dir" && npm ci )
    fi
}

run_design() {
    in_repo design python3 scripts/validate.py
}

run_backend() {
    in_repo backend cargo test --manifest-path server/Cargo.toml
}

run_web() {
    npm_install_if_needed web &&
        in_repo web npm run build &&
        in_repo web npm run test
}

run_tv_web() {
    npm_install_if_needed tv-web &&
        in_repo tv-web npm run typecheck &&
        in_repo tv-web npm run test
}

run_desktop() {
    npm_install_if_needed desktop &&
        in_repo desktop cargo test --manifest-path src-tauri/Cargo.toml
}

run_core() {
    in_repo core cargo test
}

run_video() {
    npm_install_if_needed video &&
        in_repo video npm run check
}

run_tauri_video_plugin() {
    npm_install_if_needed tauri-video-plugin &&
        in_repo tauri-video-plugin npm run check &&
        in_repo tauri-video-plugin cargo test
}

run_android() {
    # Heavy: needs JDK 17, Android SDK Platform 36, Rust Android targets and
    # cargo-ndk (scripts/prepare-core.sh). On the shared memory-constrained
    # server keep local Gradle and emulators off; rely on the hosted workflow.
    in_repo android bash scripts/prepare-core.sh &&
        in_repo android ./gradlew test
}

run_roku() {
    printf '==> [roku] no local check command.\n'
    printf '    CI stages BrighterScript 0.73.1 and runs scripts/package.py on the staging tree.\n'
    printf '    Read roku/README.md and roku/AGENTS.md; device testing is coordinated with the owner.\n'
}

run_github() {
    printf '==> [.github] organization profile only; no check commands.\n'
}

run_all() {
    failures=0
    for target in design backend web tv-web desktop core video tauri-video-plugin android roku github; do
        if run_target "$target"; then
            printf '==> %s: OK\n' "$target"
        else
            printf '==> %s: FAILED\n' "$target" >&2
            failures=$((failures + 1))
        fi
    done
    if [ "$failures" -gt 0 ]; then
        printf '%d target(s) failed\n' "$failures" >&2
        return 1
    fi
    return 0
}

run_target() {
    case "$1" in
        design) run_design ;;
        backend) run_backend ;;
        web) run_web ;;
        tv-web) run_tv_web ;;
        desktop) run_desktop ;;
        core) run_core ;;
        video) run_video ;;
        tauri-video-plugin) run_tauri_video_plugin ;;
        android) run_android ;;) run_mediamp ;;
        roku) run_roku ;;
        github) run_github ;;
        all) run_all ;;
        *)
            printf 'unknown target: %s\n' "$1" >&2
            usage >&2
            return 2
            ;;
    esac
}

usage() {
    printf 'usage: ./run.sh <target>\n'
    printf 'targets: design backend web tv-web desktop core video tauri-video-plugin android roku github all\n'
}

list() {
    printf 'design             python3 scripts/validate.py\n'
    printf 'backend            cargo test --manifest-path server/Cargo.toml\n'
    printf 'web                npm run build && npm run test\n'
    printf 'tv-web             npm run typecheck && npm run test\n'
    printf 'desktop            cargo test --manifest-path src-tauri/Cargo.toml\n'
    printf 'core               cargo test\n'
    printf 'video              npm run check\n'
    printf 'tauri-video-plugin npm run check && cargo test\n'
    printf 'android            bash scripts/prepare-core.sh && ./gradlew test (provisioned machine only)\n'
    printf 'mediamp            gradle compile + unit-test assembly tasks (JDK 17, SDK 35)\n'
    printf 'roku               no local check; CI packaging, see roku/README.md\n'
    printf 'github             organization profile only\n'
    printf 'all                run every target above\n'
}

if [ "$#" -lt 1 ]; then
    usage >&2
    exit 2
fi

for target in "$@"; do
    case "$target" in
        list) list ;;
        *) run_target "$target" || exit 1 ;;
    esac
done
