#!/usr/bin/env bash
# Print the /work frontier: open ready-for-agent issues an agent may start.
# Usage: scripts/agents/frontier.sh [repo]   (default: every viptv-org repo)
# An issue qualifies when it is unassigned, has no open blocker and no linked
# branch, and is trusted: written by a maintainer, or its ready-for-agent
# label was applied by one (docs/agents/maintainers.txt).
set -euo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib/root.sh"
mapfile -t trusted < <(grep -v '^\s*\(#\|$\)' "$WS_ROOT/docs/agents/maintainers.txt")
is_trusted() { local who; for who in "${trusted[@]}"; do [ "${1,,}" = "${who,,}" ] && return 0; done; return 1; }
filter=(--owner viptv-org); [ $# -gt 0 ] && filter=(--repo "viptv-org/$1")

page=50
mapfile -t queue < <(gh search issues "${filter[@]}" --state open --label ready-for-agent --limit 200 \
    --json repository,number,title,assignees,author,createdAt \
    --jq 'sort_by(.createdAt)[] | select(.assignees|length==0) | [.repository.name, (.number|tostring), .author.login, .title] | @tsv')

for ((first = 0; first < ${#queue[@]}; first += page)); do
    query='query{'
    for ((i = first; i < first + page && i < ${#queue[@]}; i++)); do
        IFS=$'\t' read -r repo n author _ <<< "${queue[i]}"
        query+=" i$((i - first)): repository(owner:\"viptv-org\",name:\"$repo\"){issue(number:$n){"
        query+='issueDependenciesSummary{blockedBy} linkedBranches(first:1){totalCount}'
        if ! is_trusted "$author"; then
            query+='timelineItems(last:100,itemTypes:[LABELED_EVENT]){nodes{... on LabeledEvent{actor{login} label{name}}}}'
        fi
        query+='}}'
    done
    query+='}'
    gh api graphql -f query="$query" |
        jq -r '.data | to_entries[] | [(.key[1:] | tonumber), .value.issue.issueDependenciesSummary.blockedBy, .value.issue.linkedBranches.totalCount, ([.value.issue.timelineItems.nodes[]? | select(.label.name == "ready-for-agent")] | last.actor.login // "")] | @tsv' |
        while IFS=$'\t' read -r idx blocked branches labeler; do
            IFS=$'\t' read -r repo n author title <<< "${queue[first + idx]}"
            [ "$blocked" = 0 ] || continue
            [ "$branches" = 0 ] || continue
            if ! is_trusted "$author"; then
                is_trusted "$labeler" || { echo "skip $repo#$n (untrusted: $author)" >&2; continue; }
            fi
            printf '%s#%s\t%s\n' "$repo" "$n" "$title"
        done
done
