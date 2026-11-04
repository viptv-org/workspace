#!/usr/bin/env bash
# Claim an issue for /work: linked branch + worktree, assignee, claim comment.
# Usage: scripts/agents/claim.sh <repo> <issue> <kind>/<issue>-<slug>
set -euo pipefail
repo=$1 n=$2 branch=$3
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$here/lib/root.sh"
# Backend tests break inside the workspace (Zeron port probes), so it lives in /tmp.
if [ "$repo" = backend ]; then wt=/tmp/viptv-wt/backend-$n/backend; mkdir -p "/tmp/viptv-wt/backend-$n"
elif [ "$repo" = workspace ]; then wt=$ORG_ROOT/.worktrees/workspace-$n/workspace
else wt=$ORG_ROOT/.worktrees/$repo-$n/$repo; fi
repo_dir=$ORG_ROOT/$repo; [ "$repo" = workspace ] && repo_dir=$WS_ROOT
cd "$repo_dir"
git fetch -q origin
# app and backend take unbuilt merges on edge; the batch gate promotes green edge to main.
base=main; case $repo in app|backend) base=edge ;; esac
if ! gh issue develop "$n" -R "viptv-org/$repo" --name "$branch" --base "$base" --checkout --worktree "$wt" >/dev/null; then
    echo "gh issue develop failed for $repo#$n; falling back to git worktree + push" >&2
    mkdir -p -- "$(dirname "$wt")"
    git worktree add -q -b "$branch" "$wt" "origin/$base" || { echo "fallback worktree add failed" >&2; exit 1; }
    git -C "$wt" push -q -u origin "$branch" || { echo "fallback push failed" >&2; exit 1; }
fi
gh issue edit "$n" -R "viptv-org/$repo" --add-assignee @me >/dev/null
gh issue comment "$n" -R "viptv-org/$repo" --body "Claimed by /work; branch $branch." >/dev/null
if [ "$repo" = app ]; then
    cp local.properties "$wt/"
    git -C "$wt" submodule update -q --init native/core
fi
echo "$repo#$n -> $wt ($(git -C "$wt" branch --show-current))"
