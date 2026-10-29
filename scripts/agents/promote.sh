#!/usr/bin/env bash
# Promote a gate-tested edge commit to main (fast-forward only) and close the
# issues its PRs name. Closing keywords only fire on the default branch, so
# PRs merged into edge leave their issues open until this runs.
# Usage: scripts/agents/promote.sh <repo> <tested-sha> [<tag>]
set -euo pipefail
repo=$1 sha=$2 tag=${3:-}
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root/$repo"
git fetch -q origin
old=$(git rev-parse origin/main)
git merge-base --is-ancestor "$old" "$sha" || { echo "main ($old) is not an ancestor of $sha; refusing" >&2; exit 1; }
[ "$old" = "$(git rev-parse "$sha")" ] && { echo "main already at $sha"; exit 0; }
git push -q origin "$sha:refs/heads/main"
echo "promoted $repo main ${old:0:7} -> ${sha:0:7}"
# PR numbers: "Merge pull request #N" (merge commits) or "... (#N)" (squash).
prs=$(git log --format=%s "$old..$sha" | sed -nE 's/^Merge pull request #([0-9]+).*/\1/p; s/.*\(#([0-9]+)\)$/\1/p' | sort -un)
for pr in $prs; do
    gh pr view "$pr" -R "viptv-org/$repo" --json body --jq .body 2>/dev/null |
        grep -oiE "(close[sd]?|fix(e[sd])?|resolve[sd]?) viptv-org/$repo#[0-9]+" | grep -oE '[0-9]+$' | sort -u |
        while read -r n; do
            [ "$(gh issue view "$n" -R "viptv-org/$repo" --json state --jq .state)" = OPEN ] || continue
            gh issue close "$n" -R "viptv-org/$repo" --comment "Promoted to main in ${sha:0:7}${tag:+ ($tag)} via #$pr." >/dev/null && echo "closed $repo#$n (PR #$pr)"
        done || true   # a PR with no closing line must not stop the rest
done
