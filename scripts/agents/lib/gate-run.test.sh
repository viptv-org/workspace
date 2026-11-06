#!/usr/bin/env bash
# Checks the batch gates' per-run log setup (lib/gate-run.sh): two runs of the
# same repo never share a log directory, a second run refuses while the first
# holds the lock, different repos run at once, and every gate uses the shared
# setup instead of a fixed log path.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GATE_LOG_ROOT=$tmp/logs GATE_LOCK_ROOT=$tmp/locks
mkdir -p "$GATE_LOCK_ROOT"
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

# gate_setup <repo> <sha> <hold-seconds>: takes the lock and the log directory
# the way a gate does, prints the directory, then holds the lock for a while.
gate_setup() {
    bash -c '. "$1/gate-run.sh"; gate_lock "$2" || exit $?; gate_logs "$2" "$3" || exit $?; sleep "$4"' \
        _ "$here" "$1" "$2" "$3"
}

# wait_for_dir <file>: returns once gate_setup has printed its directory.
wait_for_dir() {
    for _ in $(seq 1 100); do
        [ -s "$1" ] && return 0
        sleep 0.05
    done
    return 1
}

echo "two runs of the same repo:"
gate_setup app 1111111aaaa 3 > "$tmp/app-a.out" 2>&1 &
first=$!
wait_for_dir "$tmp/app-a.out" || fail "the first app gate printed no log directory"
gate_setup app 2222222bbbb 0 > "$tmp/app-b.out" 2>&1
second=$?
wait "$first" || fail "the first app gate failed"
app_a=$(sed -n 's/^logs //p' "$tmp/app-a.out")
app_b=$(sed -n 's/^logs //p' "$tmp/app-b.out")
[ "$second" = 4 ] || fail "the second app gate exited $second, expected 4: $(cat "$tmp/app-b.out")"
grep -q refusing "$tmp/app-b.out" || fail "the second app gate did not say it refuses: $(cat "$tmp/app-b.out")"
[ -d "$app_a" ] || fail "the first app gate's log directory is gone: $app_a"
[ -z "$app_b" ] || fail "the refused gate still made a log directory: $app_b"
[ "$(find "$tmp/logs/app" -mindepth 1 -maxdepth 1 -type d | wc -l)" = 1 ] ||
    fail "app has $(find "$tmp/logs/app" -mindepth 1 -maxdepth 1 -type d | wc -l) log directories, expected 1"
case $app_a in
    "$tmp"/logs/app/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z-1111111-*) ;;
    *) fail "log directory is not <repo>/<timestamp>-<sha>-$app_a" ;;
esac
echo "  $app_a"

echo "two repos at once:"
gate_setup app 3333333cccc 2 > "$tmp/app-c.out" 2>&1 &
app_pid=$!
gate_setup backend 4444444dddd 2 > "$tmp/backend.out" 2>&1 &
backend_pid=$!
wait "$app_pid" || fail "the app gate failed while a backend gate ran"
wait "$backend_pid" || fail "the backend gate failed while an app gate ran"
app_c=$(sed -n 's/^logs //p' "$tmp/app-c.out")
backend_d=$(sed -n 's/^logs //p' "$tmp/backend.out")
[ -d "$app_c" ] && [ -d "$backend_d" ] || fail "concurrent gates did not both get a log directory"
[ "$app_c" != "$backend_d" ] || fail "both gates shared the log directory $app_c"
case $backend_d in "$tmp"/logs/backend/*-4444444-*) ;; *) fail "backend log directory: $backend_d" ;; esac
echo "  $app_c"
echo "  $backend_d"

echo "the lock is free again after the first run:"
gate_setup app 5555555eeee 0 > "$tmp/app-d.out" 2>&1 || fail "an app gate was refused after the earlier one exited"
app_d=$(sed -n 's/^logs //p' "$tmp/app-d.out")
[ -d "$app_d" ] && [ "$app_d" != "$app_a" ] || fail "the next app gate reused or lost $app_a"
echo "  $app_d"

echo "a log directory without the lock is refused:"
bash -c '. "$1/gate-run.sh"; gate_logs app 6666666ffff' _ "$here" > "$tmp/unlocked.out" 2>&1
unlocked=$?
[ "$unlocked" = 2 ] || fail "gate_logs without gate_lock exited $unlocked, expected 2: $(cat "$tmp/unlocked.out")"
[ "$(find "$tmp/logs/app" -mindepth 1 -maxdepth 1 -type d | wc -l)" = 3 ] ||
    fail "gate_logs without the lock still made a directory: $(find "$tmp/logs/app" -mindepth 1 -maxdepth 1 -type d)"

echo "every gate uses the shared setup:"
for gate in "$here"/../*-batch-gate.sh; do
    name=$(basename "$gate")
    grep -q 'lib/gate-run.sh' "$gate" || fail "$name does not source lib/gate-run.sh"
    grep -q 'gate_lock ' "$gate" || fail "$name does not take its repo's lock"
    grep -q 'gate_logs ' "$gate" || fail "$name does not use a per-run log directory"
    fixed=$(grep -nE '>[[:space:]]*"?/tmp/[^"]*\.log' "$gate")
    [ -z "$fixed" ] || fail "$name writes a fixed log path: $fixed"
done

echo "run directories older than a week are pruned:"
old=$tmp/logs/app/20000101T000000Z-9999999-old0
young=$tmp/logs/app/20000102T000000Z-9999999-new0
mkdir -p "$old" "$young"
touch -d '8 days ago' "$old" "$young"
touch "$young"
gate_setup app 7777777aaaa 0 > "$tmp/app-e.out" 2>&1 || fail "an app gate failed after pruning"
[ -d "$old" ] && fail "the 8-day-old run directory survived: $old"
[ -d "$young" ] || fail "the run directory touched today was pruned: $young"

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "PASS"
