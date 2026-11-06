#!/usr/bin/env bash
# Per-run log directory and per-repo lock for the batch gates: two gates of the
# same repo never write the same log file, and a second one refuses while the
# first holds the lock. Source this file, then:
#
#   gate_lock <repo> || exit          # <GATE_LOCK_ROOT>/viptv-gate-<repo>.lock
#   gate_logs <repo> <sha> || exit    # creates and exports GATE_LOG_DIR
#
# gate_logs prints "logs <dir>", so a gate's own output names its log path, and
# refuses when the repo's lock is not held. The lock lives on fd 8; a command
# that leaves a daemon behind closes it with 8>&-, or that daemon holds the gate
# lock for as long as it runs.
#
# Overrides: GATE_LOG_ROOT (default /tmp/viptv-gate-logs),
# GATE_LOCK_ROOT (default /tmp), GATE_LOG_KEEP_DAYS (default 7).
# The test sets the roots to a scratch directory.

gate_log_root() {
    echo "${GATE_LOG_ROOT:-/tmp/viptv-gate-logs}/$1"
}

gate_lock() {
    local repo=$1 root running
    GATE_LOCK=${GATE_LOCK_ROOT:-/tmp}/viptv-gate-$repo.lock
    GATE_LOCK_REPO=
    exec 8>>"$GATE_LOCK" || return 2
    if ! flock -n 8; then
        root=$(gate_log_root "$repo")
        running=$(ls -dt "$root"/*/ 2>/dev/null | head -1)
        echo "gate $repo: another run holds $GATE_LOCK; refusing${running:+ (recent logs: $running)}" >&2
        return 4
    fi
    GATE_LOCK_REPO=$repo
}

gate_logs() {
    local root
    [ "${GATE_LOCK_REPO:-}" = "$1" ] || { echo "gate $1: gate_logs needs gate_lock $1 first" >&2; return 2; }
    root=$(gate_log_root "$1")
    mkdir -p "$root" || return 2
    find "$root" -mindepth 1 -maxdepth 1 -type d -mtime +"${GATE_LOG_KEEP_DAYS:-7}" -exec rm -rf {} + 2>/dev/null || true
    GATE_LOG_DIR=$(mktemp -d "$root/$(date -u +%Y%m%dT%H%M%SZ)-${2:0:7}-XXXX") || return 2
    export GATE_LOG_DIR
    echo "logs $GATE_LOG_DIR"
}
