#!/usr/bin/env bash
# Run a heavy Gradle/cargo command in one of VIPTV_HEAVY_SLOTS lock slots
# (default 3). Slot 1 is /tmp/viptv-heavy-build.lock, so plain
# `flock /tmp/viptv-heavy-build.lock …` callers still take a slot.
# Usage: scripts/agents/heavy.sh ./gradlew --max-workers=1 :composeApp:desktopTest
set -u
slots=${VIPTV_HEAVY_SLOTS:-3}
[ $# -gt 0 ] || { echo "usage: $0 <command> [args...]" >&2; exit 2; }
while :; do
    for i in $(seq 1 "$slots"); do
        lock=/tmp/viptv-heavy-build.lock; [ "$i" -gt 1 ] && lock=/tmp/viptv-heavy-build-$i.lock
        exec 9>>"$lock"
        if flock -n 9; then exec "$@"; fi   # the command inherits fd 9 and holds the slot until it exits
        exec 9>&-
    done
    sleep 5
done
