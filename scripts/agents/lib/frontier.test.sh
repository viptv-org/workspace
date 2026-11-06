#!/usr/bin/env bash
# Checks scripts/agents/frontier.sh: the batched frontier lists what the
# per-issue calls listed, one call per page of candidates.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
frontier=$here/../frontier.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

export FAKE_GH_CALLS=$tmp/calls FAKE_GH_FIXTURE=$tmp/fixture.json
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
# Serves $FAKE_GH_FIXTURE the way GitHub would and records every call.
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_CALLS"
args=("$@")
prog=
for ((i = 0; i < ${#args[@]}; i++)); do
    [ "${args[i]}" = --jq ] && prog=${args[i + 1]}
done
node() {
    jq -c --arg repo "$1" --argjson n "$2" \
        'map(select(.repository.name == $repo and .number == $n)) | first' "$FAKE_GH_FIXTURE"
}
case ${args[0]} in
search)
    jq -r "$prog" "$FAKE_GH_FIXTURE"
    ;;
api)
    if [ "${args[1]}" = graphql ]; then
        query=${args[3]#query=}
        data='{}'
        while read -r alias repo n asked; do
            issue=$(jq -c --argjson asked "$asked" 'if . == null then null else {issue: {
                issueDependenciesSummary: {blockedBy: (.blockedByOpen // 0)},
                linkedBranches: {totalCount: (.branches // 0)},
                timelineItems: (if $asked == 1 then {nodes: [(.labelEvents // [])[] | {actor: {login: .actor}, label: {name: .label}}]} else null end)}} end' \
                <<<"$(node "$repo" "$n")")
            data=$(jq -c --arg alias "$alias" --argjson issue "$issue" '. + {($alias): $issue}' <<<"$data")
        done < <(sed -E 's/ (i[0-9]+): /\n\1: /g' <<<"$query" | grep -E '^i[0-9]+: ' |
            while read -r chunk; do
                alias=${chunk%%:*}
                repo=$(sed -E 's/.*name:"([^"]*)".*/\1/' <<<"$chunk")
                n=$(sed -E 's/.*issue\(number:([0-9]+).*/\1/' <<<"$chunk")
                case $chunk in *timelineItems*) asked=1 ;; *) asked=0 ;; esac
                printf '%s %s %s %s\n' "$alias" "$repo" "$n" "$asked"
            done)
        jq -c --argjson data "$data" '{data: $data}' <<<"{}"
        exit 0
    fi
    rest=${args[1]#repos/viptv-org/}
    repo=${rest%%/*}; rest=${rest#*/}
    rest=${rest#issues/}
    n=${rest%%/*}; what=${rest#"$n"}; what=${what#/}
    case $what in
    '') jq -r "$prog" <<<"$(jq -c '{issue_dependencies_summary: {blocked_by: (.blockedByOpen // 0)}}' <<<"$(node "$repo" "$n")")" ;;
    events) jq -r "$prog" <<<"$(jq -c '[ (.labelEvents // [])[] | {event: "labeled", label: {name: .label}, actor: {login: .actor}} ]' <<<"$(node "$repo" "$n")")" ;;
    *) echo "fake gh: unsupported path ${args[1]}" >&2; exit 1 ;;
    esac
    ;;
issue)
    n= repo=
    for ((i = 0; i < ${#args[@]}; i++)); do
        case ${args[i]} in --list) n=${args[i + 1]} ;; -R) repo=${args[i + 1]#viptv-org/} ;; esac
    done
    [ "$(jq -r '.branches // 0' <<<"$(node "$repo" "$n")")" = 0 ] || printf 'some-branch\thttps://example.invalid\n'
    ;;
*)
    echo "fake gh: unsupported command $*" >&2; exit 1
    ;;
esac
FAKE
chmod +x "$tmp/bin/gh"
export PATH=$tmp/bin:$PATH

cat > "$FAKE_GH_FIXTURE" <<'JSON'
[
 {"repository":{"name":"app"},"number":1,"title":"trusted, ready","assignees":[],"author":{"login":"Gratenes"},"createdAt":"2026-01-01T00:00:00Z","blockedByOpen":0,"branches":0},
 {"repository":{"name":"app"},"number":2,"title":"trusted, one open blocker","assignees":[],"author":{"login":"Gratenes"},"createdAt":"2026-01-02T00:00:00Z","blockedByOpen":1,"branches":0},
 {"repository":{"name":"app"},"number":3,"title":"trusted, linked branch","assignees":[],"author":{"login":"vynxc"},"createdAt":"2026-01-03T00:00:00Z","blockedByOpen":0,"branches":1},
 {"repository":{"name":"app"},"number":4,"title":"already assigned","assignees":[{"login":"vynxc"}],"author":{"login":"Gratenes"},"createdAt":"2026-01-04T00:00:00Z","blockedByOpen":0,"branches":0},
 {"repository":{"name":"backend"},"number":5,"title":"outsider filed, a maintainer labelled it","assignees":[],"author":{"login":"stranger"},"createdAt":"2026-01-05T00:00:00Z","blockedByOpen":0,"branches":0,
  "labelEvents":[{"actor":"stranger","label":"bug"},{"actor":"vynxc","label":"ready-for-agent"}]},
 {"repository":{"name":"backend"},"number":6,"title":"outsider filed, only they labelled it","assignees":[],"author":{"login":"stranger"},"createdAt":"2026-01-06T00:00:00Z","blockedByOpen":0,"branches":0,
  "labelEvents":[{"actor":"stranger","label":"ready-for-agent"}]},
 {"repository":{"name":"backend"},"number":7,"title":"outsider filed, relabelled by a maintainer","assignees":[],"author":{"login":"stranger"},"createdAt":"2026-01-07T00:00:00Z","blockedByOpen":0,"branches":0,
  "labelEvents":[{"actor":"stranger","label":"ready-for-agent"},{"actor":"Gratenes","label":"bug"},{"actor":"Gratenes","label":"ready-for-agent"}]},
 {"repository":{"name":"backend"},"number":8,"title":"outsider filed, a maintainer untagged it again","assignees":[],"author":{"login":"stranger"},"createdAt":"2026-01-08T00:00:00Z","blockedByOpen":0,"branches":0,
  "labelEvents":[{"actor":"Gratenes","label":"ready-for-agent"},{"actor":"stranger","label":"ready-for-agent"}]}
]
JSON

# The per-issue path frontier.sh replaced, kept as the oracle it must match.
trusted=(Gratenes vynxc)
is_trusted() { local who; for who in "${trusted[@]}"; do [ "${1,,}" = "${who,,}" ] && return 0; done; return 1; }
per_issue() {
    gh search issues --owner viptv-org --state open --label ready-for-agent --limit 200 \
        --json repository,number,title,assignees,author,createdAt \
        --jq 'sort_by(.createdAt)[] | select(.assignees|length==0) | [.repository.name, (.number|tostring), .author.login, .title] | @tsv' |
    while IFS=$'\t' read -r repo n author title; do
        [ "$(gh api "repos/viptv-org/$repo/issues/$n" --jq .issue_dependencies_summary.blocked_by)" = 0 ] || continue
        [ -z "$(gh issue develop --list "$n" -R "viptv-org/$repo" 2>/dev/null)" ] || continue
        if ! is_trusted "$author"; then
            labeler=$(gh api "repos/viptv-org/$repo/issues/$n/events" --paginate \
                --jq '[.[] | select(.event=="labeled" and .label.name=="ready-for-agent")] | last | .actor.login // empty')
            is_trusted "${labeler:-}" || { echo "skip $repo#$n (untrusted: $author)" >&2; continue; }
        fi
        printf '%s#%s\t%s\n' "$repo" "$n" "$title"
    done
}

echo "the batched frontier matches the per-issue calls:"
per_issue > "$tmp/old.out" 2> "$tmp/old.err"
bash "$frontier" > "$tmp/new.out" 2> "$tmp/new.err"
diff -u "$tmp/old.out" "$tmp/new.out" >&2 || fail "stdout differs from the per-issue path"
diff -u "$tmp/old.err" "$tmp/new.err" >&2 || fail "stderr differs from the per-issue path"

cat > "$tmp/want.out" <<'OUT'
app#1	trusted, ready
backend#5	outsider filed, a maintainer labelled it
backend#7	outsider filed, relabelled by a maintainer
OUT
printf 'skip backend#6 (untrusted: stranger)\nskip backend#8 (untrusted: stranger)\n' > "$tmp/want.err"
diff -u "$tmp/want.out" "$tmp/new.out" >&2 || fail "the frontier listed the wrong issues"
diff -u "$tmp/want.err" "$tmp/new.err" >&2 || fail "the frontier skipped the wrong issues"

echo "one call per page of candidates, not two per issue:"
: > "$FAKE_GH_CALLS"
bash "$frontier" > /dev/null 2>&1
calls=$(wc -l < "$FAKE_GH_CALLS")
[ "$calls" = 2 ] || fail "8 candidates took $calls gh calls, expected 2 (one search, one page)"
[ "$(grep -c 'api graphql' "$FAKE_GH_CALLS")" = 1 ] || fail "the per-issue facts did not come back in one GraphQL call"

jq -n '[range(0; 60) as $i | {repository: {name: "app"}, number: (100 + $i), title: ("queued \($i)"),
        assignees: [], author: {login: "Gratenes"},
        createdAt: ("2026-02-01T00:" + (if $i < 10 then "0" else "" end) + ($i | tostring) + ":00Z"),
        blockedByOpen: 0, branches: 0}]' > "$FAKE_GH_FIXTURE"
: > "$FAKE_GH_CALLS"
bash "$frontier" > "$tmp/many.out" 2>&1
calls=$(wc -l < "$FAKE_GH_CALLS")
[ "$calls" = 3 ] || fail "60 candidates took $calls gh calls, expected 3 (one search, two pages)"
[ "$(wc -l < "$tmp/many.out")" = 60 ] || fail "60 candidates listed $(wc -l < "$tmp/many.out") issues"
: > "$FAKE_GH_CALLS"
per_issue > /dev/null 2>&1
per_issue_calls=$(wc -l < "$FAKE_GH_CALLS")
[ "$per_issue_calls" -gt 100 ] || fail "the per-issue path took only $per_issue_calls calls for 60 candidates"
echo "  60 candidates: 3 calls (per-issue: $per_issue_calls)"

echo "a repo filter reaches the search:"
: > "$FAKE_GH_CALLS"
bash "$frontier" app > /dev/null 2>&1
grep -q -- '--repo viptv-org/app' "$FAKE_GH_CALLS" || fail "frontier.sh app did not search one repo"

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "PASS"