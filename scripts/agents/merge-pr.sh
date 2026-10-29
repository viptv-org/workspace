#!/usr/bin/env bash
# Merge a /work PR and clean up its worktree and branches only once GitHub confirms the merge.
# Usage: scripts/agents/merge-pr.sh <repo> <pr>
set -euo pipefail
repo=$1 pr=$2
root=$(cd "$(dirname "$0")/../.." && pwd)
read -r head branch < <(gh pr view "$pr" -R "viptv-org/$repo" --json headRefOid,headRefName --jq '"\(.headRefOid) \(.headRefName)"')
method=merge; case $repo in backend|design) method=squash ;; esac
merged=$(gh api -X PUT "repos/viptv-org/$repo/pulls/$pr/merge" -f merge_method=$method -f sha="$head" --jq .merged 2>&1) || true
[ "$merged" = true ] || { echo "NOT merged $repo#$pr: $merged" >&2; exit 1; }
echo "merged $repo#$pr ($method)"
cd "$root/$repo"
git push -q origin --delete "$branch" 2>/dev/null || true
wt=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{w=$2} $0=="branch " b {print w}')
if [ -n "$wt" ]; then
    timeout 110 git worktree remove --force "$wt" || true
    case $wt in */"$repo") rm -rf "$(dirname "$wt")" ;; esac
fi
git branch -D "$branch" >/dev/null 2>&1 || true
git worktree prune
echo "cleaned ${wt:-no worktree} and $branch"
