#!/usr/bin/env bash
# Fast-forward this repository (the workspace notes) and every cloned
# organization repository. A repository that cannot be fast-forwarded (local
# changes or a diverged branch) is reported, never reverted.
#
# Written for bash on Linux, macOS, and Git Bash (Git for Windows).
set -u

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ -d "$SCRIPT_DIR/../design" ] && [ ! -d "$SCRIPT_DIR/design" ]; then
    cd "$SCRIPT_DIR/.."
else
    cd "$SCRIPT_DIR"
fi

REPOS="design backend web tv-web desktop core video tauri-video-plugin android mediamp roku .github"
failures=0

update_one() {
    label=$1
    dir=$2
    if [ ! -d "$dir/.git" ]; then
        printf '==> %s: not cloned, skipping (run ./setup.sh)\n' "$label"
        return 0
    fi
    printf '==> updating %s\n' "$label"
    if ! git -C "$dir" pull --ff-only; then
        printf 'error: %s: fast-forward failed (uncommitted changes or diverged branch)\n' "$label" >&2
        failures=$((failures + 1))
    fi
}

update_one "workspace (this repository)" "."
for repo in $REPOS; do
    update_one "$repo" "$repo"
done

printf '\n'
if [ "$failures" -gt 0 ]; then
    printf 'update finished with %d failure(s)\n' "$failures" >&2
    exit 1
fi
printf 'All repositories are up to date.\n'
