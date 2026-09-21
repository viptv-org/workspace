#!/usr/bin/env bash
# VIPTV workspace bootstrap.
#
# Clones every viptv-org repository into this repository's root so that a
# single clone becomes the working directory for the whole organization,
# reproducing the canonical viptv-org layout. Re-running is safe: existing
# directories are skipped.
#
# Written for bash on Linux, macOS, and Git Bash (Git for Windows). No
# GNU-only flags are used.
set -eu

# Resolve this repository's root without readlink -f (not portable).
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if [ -d "$SCRIPT_DIR/../design" ] && [ ! -d "$SCRIPT_DIR/design" ]; then
    cd "$SCRIPT_DIR/.."
else
    cd "$SCRIPT_DIR"
fi

# Repositories in the canonical viptv-org layout.
REPOS="design backend web tv-web desktop core video tauri-video-plugin android roku .github"

# Clone source. Defaults to https://github.com/viptv-org/<repo>.git. Derived
# from this repository's own origin when that origin is a remote URL pointing
# at the workspace repo, so forks and mirrors work unchanged. Override with
# VIPTV_ORG_REMOTE. Local-path origins fall back to the default.
ORG_REMOTE=${VIPTV_ORG_REMOTE:-}
if [ -z "$ORG_REMOTE" ] && ORIGIN=$(git remote get-url origin 2>/dev/null); then
    case "$ORIGIN" in
        http://*|https://*|ssh://*|git@*)
            case "$ORIGIN" in
                */workspace.git) ORG_REMOTE=${ORIGIN%/workspace.git} ;;
                */workspace) ORG_REMOTE=${ORIGIN%/workspace} ;;
            esac
            ;;
    esac
fi
: "${ORG_REMOTE:=https://github.com/viptv-org}"
printf '==> cloning from %s\n' "$ORG_REMOTE"

failures=0
for repo in $REPOS; do
    if [ -e "$repo" ]; then
        printf '==> %s: already present, skipping\n' "$repo"
        continue
    fi
    printf '==> cloning %s\n' "$repo"
    if ! git clone "${ORG_REMOTE}/${repo}.git" "$repo"; then
        printf 'error: failed to clone %s\n' "$repo" >&2
        failures=$((failures + 1))
    fi
done

printf '\n'
if [ "$failures" -gt 0 ]; then
    printf 'setup finished with %d failure(s); fix the cause and re-run\n' "$failures" >&2
    exit 1
fi
printf 'Workspace ready.\n'
printf '  ./update.sh     fast-forward this repo and every clone\n'
printf '  ./run.sh list   show each repository check command\n'
printf '  ./run.sh all    run every repository check\n'
