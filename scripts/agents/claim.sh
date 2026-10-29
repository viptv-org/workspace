#!/usr/bin/env bash
# Claim an issue for /work: linked branch + worktree, assignee, claim comment.
# Usage: scripts/agents/claim.sh <repo> <issue> <kind>/<issue>-<slug>
set -euo pipefail
repo=$1 n=$2 branch=$3
root=$(cd "$(dirname "$0")/../.." && pwd)
# Backend tests break inside the workspace (Zeron port probes), so it lives in /tmp.
if [ "$repo" = backend ]; then wt=/tmp/viptv-wt/backend-$n/backend; mkdir -p "/tmp/viptv-wt/backend-$n"
elif [ "$repo" = workspace ]; then wt=$root/.worktrees/workspace-$n
else wt=$root/.worktrees/$repo-$n/$repo; fi
repo_dir=$root/$repo; [ "$repo" = workspace ] && repo_dir=$root
cd "$repo_dir"
git fetch -q origin
# app and backend take unbuilt merges on edge; the batch gate promotes green edge to main.
base=main; case $repo in app|backend) base=edge ;; esac
gh issue develop "$n" -R "viptv-org/$repo" --name "$branch" --base "$base" --checkout --worktree "$wt" >/dev/null
gh issue edit "$n" -R "viptv-org/$repo" --add-assignee @me >/dev/null
gh issue comment "$n" -R "viptv-org/$repo" --body "Claimed by /work; branch $branch." >/dev/null
if [ "$repo" = app ]; then
    cp local.properties "$wt/"
    git -C "$wt" submodule update -q --init native/core
fi
echo "$repo#$n -> $wt ($(git -C "$wt" branch --show-current))"
