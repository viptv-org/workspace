#!/usr/bin/env bash
# Batch gate for viptv-org/backend (/work step 5). PRs merge unbuilt into edge;
# this runs the documented checks once on edge in its own worktree (the main
# clone stays on main for the dev instance). Green -> promote edge to main
# (fast-forward, closing the promoted PRs' issues). Red -> main is untouched.
set -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
branch=${GATE_BRANCH:-edge}
wt=/tmp/viptv-wt/gate-backend/backend   # outside the workspace: Zeron port probes break backend tests there
cd "$root/backend" && git fetch -q origin || exit 2
if [ -d "$wt" ]; then git -C "$wt" checkout -q --detach "origin/$branch" || exit 2
else mkdir -p "$(dirname "$wt")" && git worktree add -q --detach "$wt" "origin/$branch" || exit 2; fi
cd "$wt"; sha=$(git rev-parse HEAD); rev=${sha:0:7}
export RUSTUP_TOOLCHAIN=1.98 CARGO_TARGET_DIR=/srv/fast/rust-target-backend-gate
echo "gate backend $branch $rev: cargo test + live-runtime compile + engine sync check"
python3 scripts/sync-engine.py check > /tmp/backend-gate-sync.log 2>&1 || { echo "RED $rev: engine snapshot check failed (see /tmp/backend-gate-sync.log)"; exit 1; }
"$root/scripts/agents/heavy.sh" bash -c 'cargo test --manifest-path server/Cargo.toml && cargo test --manifest-path server/Cargo.toml --features live-runtime --no-run' > /tmp/backend-gate-test.log 2>&1
code=$?
grep -E '^test result:' /tmp/backend-gate-test.log | awk '{p+=$4; f+=$6} END {print "passed=" p " failed=" f}'
[ $code = 0 ] || { echo "RED $rev: cargo test or live-runtime compile failed (see /tmp/backend-gate-test.log)"; grep -E '^test .* FAILED|^error' /tmp/backend-gate-test.log | head -10; exit 1; }
echo "GREEN $rev"
"$root/scripts/agents/promote.sh" backend "$sha" || { echo "Promote failed: main not moved"; exit 3; }
