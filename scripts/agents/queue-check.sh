#!/usr/bin/env bash
# One /work queue check, for a timer: start the batch gate for a repo whose
# edge is ahead of main, then print the brief the orchestrator acts on. The
# gate's own lock refuses a second run, and an edge commit whose gate already
# came back RED is not tested again.
# Usage: scripts/agents/queue-check.sh [--dry-run]   (from the org root)
# The gate runs detached and appends to <GATE_LAUNCH_ROOT>/<repo>.log
# (default /tmp/viptv-gate-launch).
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib/root.sh"
dry=0; [ "${1:-}" = --dry-run ] && dry=1
launches=${GATE_LAUNCH_ROOT:-/tmp/viptv-gate-launch}
mkdir -p "$launches"

echo "queue-check $(date -u +%FT%TZ)"
for repo in app backend; do
    git -C "$ORG_ROOT/$repo" fetch -q origin || { echo "gate $repo: fetch failed"; continue; }
    ahead=$(git -C "$ORG_ROOT/$repo" rev-list --count origin/main..origin/edge)
    rev=$(git -C "$ORG_ROOT/$repo" rev-parse --short=7 origin/edge)
    log=$launches/$repo.log
    if [ "$ahead" = 0 ]; then
        echo "gate $repo: edge is level with main"
    elif grep -qE "^RED $rev[: ]" "$log" 2>/dev/null; then
        echo "gate $repo: RED at $rev, not starting another (logs $log)"
    elif ! flock -n "${GATE_LOCK_ROOT:-/tmp}/viptv-gate-$repo.lock" true 2>/dev/null; then
        echo "gate $repo: running (logs $log)"
    elif [ "$dry" = 1 ]; then
        echo "gate $repo: would start, edge $ahead commits ahead of main at $rev"
    else
        setsid "$here/$repo-batch-gate.sh" >> "$log" 2>&1 < /dev/null &
        echo "gate $repo: started, edge $ahead commits ahead of main at $rev (logs $log)"
    fi
done

brief() {
    local lines=()
    mapfile -t lines < <(gh search issues --owner viptv-org --state open --label "$1" --limit 100 \
        --json repository,number,title,createdAt \
        --jq 'sort_by(.createdAt)[] | "\(.repository.name)#\(.number)\t\(.title)"')
    echo "$1 ${#lines[@]}:"
    for line in "${lines[@]}"; do echo "  $line"; done
}
mapfile -t frontier < <(bash "$here/frontier.sh" 2>&1)
echo "frontier ${#frontier[@]}:"
for line in "${frontier[@]}"; do echo "  $line"; done
brief needs-triage
mapfile -t prs < <(gh search prs --owner viptv-org --state open --limit 100 --json repository,number,title,createdAt \
    --jq 'sort_by(.createdAt)[] | "\(.repository.name)#\(.number)\t\(.title)"')
echo "prs open ${#prs[@]}:"
for line in "${prs[@]}"; do echo "  $line"; done
brief ready-for-human