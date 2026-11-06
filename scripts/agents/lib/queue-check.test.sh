#!/usr/bin/env bash
# Checks scripts/agents/queue-check.sh against a fake git and gh: a gate starts
# only for a repo whose edge is ahead of main, never for one already RED at
# that commit or while a gate runs, and the brief carries the frontier,
# needs-triage, open PRs and ready-for-human.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
queue_check=$here/../queue-check.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }
check() { grep -qF -- "$2" "$1" || fail "$3: $2 not in $(cat "$1")"; }
uncheck() { grep -qF -- "$2" "$1" && fail "$3: $2 should not be in $(cat "$1")"; }

export FAKE_GIT_CALLS=$tmp/git-calls FAKE_GH_CALLS=$tmp/gh-calls
export FAKE_GH_ISSUES=$tmp/issues.json FAKE_GH_PRS=$tmp/prs.json
export GATE_LAUNCH_ROOT=$tmp/launch GATE_LOCK_ROOT=$tmp/locks
mkdir -p "$tmp/bin" "$GATE_LOCK_ROOT"
cat > "$tmp/bin/git" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_GIT_CALLS"
path=$2
case $3 in
fetch) exit 0 ;;
rev-list) case $path in */app) echo "${FAKE_APP_AHEAD:-0}" ;; *) echo "${FAKE_BACKEND_AHEAD:-0}" ;; esac ;;
rev-parse) case $path in */app) echo "${FAKE_APP_REV:-aaaaaaa}" ;; *) echo "${FAKE_BACKEND_REV:-bbbbbbb}" ;; esac ;;
*) exit 1 ;;
esac
FAKE
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_GH_CALLS"
args=("$@")
prog= label=
for ((i = 0; i < ${#args[@]}; i++)); do
    case ${args[i]} in --jq) prog=${args[i + 1]} ;; --label) label=${args[i + 1]} ;; esac
done
case ${args[0]} in
search)
    case ${args[1]} in
    issues) jq -r --arg label "$label" 'map(select(.labels | index($label)))' "$FAKE_GH_ISSUES" | jq -r "$prog" ;;
    prs) jq -r "$prog" "$FAKE_GH_PRS" ;;
    esac
    ;;
api) echo '{"data":{}}' ;;
esac
FAKE
chmod +x "$tmp/bin/git" "$tmp/bin/gh"
export PATH=$tmp/bin:$PATH

cat > "$FAKE_GH_ISSUES" <<'JSON'
[
 {"repository":{"name":"workspace"},"number":58,"title":"frontier item","labels":["ready-for-agent"],"assignees":[],"author":{"login":"Gratenes"},"createdAt":"2026-01-01T00:00:00Z"},
 {"repository":{"name":"app"},"number":900,"title":"untriaged thing","labels":["needs-triage"],"assignees":[],"author":{"login":"Gratenes"},"createdAt":"2026-01-02T00:00:00Z"},
 {"repository":{"name":"app"},"number":901,"title":"awaiting the owner","labels":["ready-for-human"],"assignees":[],"author":{"login":"Gratenes"},"createdAt":"2026-01-03T00:00:00Z"}
]
JSON
cat > "$FAKE_GH_PRS" <<'JSON'
[
 {"repository":{"name":"workspace"},"number":69,"title":"Batch the calls","createdAt":"2026-01-04T00:00:00Z"}
]
JSON

run() {
    bash "$queue_check" --dry-run > "$tmp/out" 2> "$tmp/err"
    [ $? = 0 ] || fail "queue-check exited non-zero: $(cat "$tmp/err")"
}

echo "edge level with main starts nothing:"
FAKE_APP_AHEAD=0 FAKE_BACKEND_AHEAD=0 run
check "$tmp/out" "gate app: edge is level with main" "app level"
check "$tmp/out" "gate backend: edge is level with main" "backend level"
uncheck "$tmp/out" "would start" "level edge"

echo "edge ahead of main starts that repo's gate:"
FAKE_APP_AHEAD=3 FAKE_BACKEND_AHEAD=0 run
check "$tmp/out" "gate app: would start, edge 3 commits ahead of main at aaaaaaa" "app ahead"
check "$tmp/out" "gate backend: edge is level with main" "backend still level"

echo "an edge commit already RED is not tested again:"
mkdir -p "$GATE_LAUNCH_ROOT"
printf 'gate edge aaaaaaa: desktopTest + compileKotlinWasmJs\nRED aaaaaaa: desktopTest or web compile failed (see %s)\n' "$tmp/desktopTest.log" > "$GATE_LAUNCH_ROOT/app.log"
FAKE_APP_AHEAD=3 run
check "$tmp/out" "gate app: RED at aaaaaaa, not starting another (logs $GATE_LAUNCH_ROOT/app.log)" "RED guard"
uncheck "$tmp/out" "would start" "RED guard"
echo "a new edge commit is tested:"
FAKE_APP_AHEAD=4 FAKE_APP_REV=ccccccc run
check "$tmp/out" "would start, edge 4 commits ahead of main at ccccccc" "new commit after RED"
rm -f "$GATE_LAUNCH_ROOT/app.log"

echo "a held gate lock starts nothing:"
( exec 8>>"$GATE_LOCK_ROOT/viptv-gate-app.lock"; flock -n 8; sleep 2 ) &
holder=$!
sleep 0.3
FAKE_APP_AHEAD=3 run
check "$tmp/out" "gate app: running (logs $GATE_LAUNCH_ROOT/app.log)" "gate running"
wait "$holder"
FAKE_APP_AHEAD=3 run
check "$tmp/out" "would start" "lock released"

echo "the brief carries the queue:"
: > "$FAKE_GH_CALLS"
FAKE_APP_AHEAD=3 run
check "$tmp/out" "frontier 0:" "frontier heading"
check "$tmp/out" "  app#900	untriaged thing" "needs-triage"
check "$tmp/out" "  workspace#69	Batch the calls" "open PR"
check "$tmp/out" "  app#901	awaiting the owner" "ready-for-human"
grep -q -- '--limit 200' "$FAKE_GH_CALLS" || fail "the brief did not run frontier.sh"

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "PASS"