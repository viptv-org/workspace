#!/usr/bin/env bash
# Run one repository's checks: ./run.sh <app|backend|core|design|playback-gateway|all>
set -u
cd "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

in_repo() {
    repo=$1; shift
    printf '==> [%s] %s\n' "$repo" "$*"
    ( cd "$repo" && "$@" )
}

run_app() {
    JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64} LC_ALL=C \
    VIPTV_PLAYBACK_GATEWAY=$PWD/playback-gateway RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN:-1.98.0} \
        in_repo app ./gradlew --max-workers=1 :composeApp:desktopTest :composeApp:compileAndroidMain :composeApp:compileKotlinWasmJs
}

run_backend() {
    in_repo backend python3 scripts/sync-engine.py check &&
        in_repo backend cargo test --manifest-path server/Cargo.toml &&
        in_repo backend cargo test --manifest-path server/Cargo.toml --features live-runtime --no-run
}

run_core() { in_repo core cargo test --workspace --all-features; }
run_design() { in_repo design python3 scripts/validate.py; }

run_playback_gateway() {
    [ -d playback-gateway ] || { printf '==> [playback-gateway] not cloned; skipping\n' >&2; return 0; }
    in_repo playback-gateway cargo test --locked --workspace
}

targets="app backend core design playback-gateway"

run_target() {
    case "$1" in
        app) run_app ;;
        backend) run_backend ;;
        core) run_core ;;
        design) run_design ;;
        playback-gateway) run_playback_gateway ;;
        all)
            failed=0
            for t in $targets; do run_target "$t" || { printf '==> %s: FAILED\n' "$t" >&2; failed=$((failed + 1)); }; done
            [ "$failed" = 0 ] ;;
        *) printf 'usage: ./run.sh <%s|all>\n' "$(echo $targets | tr ' ' '|')" >&2; return 2 ;;
    esac
}

run_target "${1:-}"
