#!/usr/bin/env bash
# Print the /work frontier: open ready-for-agent issues an agent may start.
# Usage: scripts/agents/frontier.sh [repo]   (default: every viptv-org repo)
# An issue qualifies when it is unassigned, has no open blocker and no linked
# branch, and is trusted: written by a maintainer, or its ready-for-agent
# label was applied by one (docs/agents/maintainers.txt).
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
mapfile -t trusted < <(grep -v '^\s*\(#\|$\)' "$here/docs/agents/maintainers.txt")
is_trusted() { local who; for who in "${trusted[@]}"; do [ "${1,,}" = "${who,,}" ] && return 0; done; return 1; }
filter=(--owner viptv-org); [ $# -gt 0 ] && filter=(--repo "viptv-org/$1")
gh search issues "${filter[@]}" --state open --label ready-for-agent --limit 200 \
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
