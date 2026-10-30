#!/usr/bin/env bash
# Merge a /work PR and clean up its worktree and branches only once GitHub confirms the merge.
# Usage: scripts/agents/merge-pr.sh <repo> <pr>
set -euo pipefail
repo=$1 pr=$2
root=$(cd "$(dirname "$0")/../.." && pwd)
read -r head branch < <(gh pr view "$pr" -R "viptv-org/$repo" --json headRefOid,headRefName --jq '"\(.headRefOid) \(.headRefName)"')
checks=$(gh pr checks "$pr" -R "viptv-org/$repo" --json name,bucket --jq '[.[]|select(.bucket!="pass" and .bucket!="skipping")|"\(.name)=\(.bucket)"]|join(" ")' 2>/dev/null || true)
[ -z "$checks" ] || [ "${FORCE:-}" = 1 ] || { echo "NOT merged $repo#$pr: checks not green: $checks (FORCE=1 overrides)" >&2; exit 2; }
method=merge; case $repo in backend|design) method=squash ;; esac
merged=$(gh api -X PUT "repos/viptv-org/$repo/pulls/$pr/merge" -f merge_method=$method -f sha="$head" --jq .merged 2>&1) || true
[ "$merged" = true ] || { echo "NOT merged $repo#$pr: $merged" >&2; exit 1; }
echo "merged $repo#$pr ($method)"
repo_dir=$root/$repo; [ "$repo" = workspace ] && repo_dir=$root
cd "$repo_dir"
git push -q origin --delete "$branch" 2>/dev/null || true
wt=$(git worktree list --porcelain | awk -v b="refs/heads/$branch" '/^worktree /{w=$2} $0=="branch " b {print w}')
case $wt in
    "$root"/.worktrees/?*/"$repo"|/tmp/viptv-wt/?*/"$repo")
        timeout 110 git worktree remove --force "$wt" || true
        rm -rf -- "$(dirname "$wt")" ;;
    "$root"/.worktrees/?*)
        timeout 110 git worktree remove --force "$wt" || true ;;
    "") ;;
    *) echo "left $wt alone: not an agent worktree" >&2; wt= ;;
esac
git branch -D "$branch" >/dev/null 2>&1 || true
git worktree prune
echo "cleaned ${wt:-no worktree} and $branch"
