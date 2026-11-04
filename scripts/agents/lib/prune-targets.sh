#!/usr/bin/env bash
# Prune stale per-issue cargo target dirs under the shared build cache and the
# shared incremental cache when the disk is over the threshold. Source this file
# and call prune_targets, or run it directly. A dir is removed only when no live
# git worktree owns it and no process has it open; rust-target-*-gate caches are
# always kept because the gate worktree lives in /tmp and clears on reboot.
#
# Overrides for tests and alternate layouts:
#   PRUNE_TARGET_ROOT        build cache root (default /srv/fast)
#   PRUNE_ORG_ROOT           org root holding the repo clones (default $ORG_ROOT)
#   PRUNE_WS_ROOT            workspace repo clone (default $WS_ROOT)
#   PRUNE_DISK_THRESHOLD     percent at which the incremental cache is dropped (default 80)

prune_targets() {
    local target_root=${PRUNE_TARGET_ROOT:-/srv/fast}
    local org_root=${PRUNE_ORG_ROOT:-$ORG_ROOT}
    local ws_root=${PRUNE_WS_ROOT:-${WS_ROOT:-$org_root}}
    local threshold=${PRUNE_DISK_THRESHOLD:-80}

    [ -d "$target_root" ] || { echo "prune: $target_root not found" >&2; return 0; }

    local -A aliases
    aliases[backend]=backend
    aliases[app]=app
    aliases[core]=core
    aliases[design]=design
    aliases[playback-gateway]="playback-gateway pg"
    aliases[workspace]=workspace

    local -A protected
    local repo main top
    for repo in backend app core design playback-gateway workspace; do
        if [ "$repo" = workspace ]; then main=$ws_root; else main=$org_root/$repo; fi
        { [ -d "$main/.git" ] || [ -f "$main/.git" ]; } || continue
        top=$(git -C "$main" rev-parse --show-toplevel 2>/dev/null) || continue
        while IFS= read -r wt; do
            [ "$wt" = "$top" ] && continue
            local base n a
            base=$(basename "$(dirname "$wt")")
            n=${base#"$repo-"}
            if [ "$n" != "$base" ] && [[ "$n" =~ ^[0-9]+$ ]]; then
                for a in ${aliases[$repo]}; do
                    protected["rust-target-$a-$n"]=1
                done
            fi
        done < <(git -C "$main" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    done

    in_use() {
        local d=$1
        if command -v lsof >/dev/null 2>&1; then
            [ -n "$(lsof -t +D "$d" 2>/dev/null | head -1)" ] && return 0
        fi
        if command -v fuser >/dev/null 2>&1; then
            fuser -s "$d" 2>/dev/null && return 0
        fi
        return 1
    }

    freed_bytes() { local b=$1; numfmt --to=iec "$b" 2>/dev/null; }

    local dir name size total=0
    for dir in "$target_root"/rust-target-*; do
        [ -e "$dir" ] || continue
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        case "$name" in *-gate) continue ;; esac
        [ -n "${protected[$name]:-}" ] && continue
        if in_use "$dir"; then
            echo "prune: keep $name (in use)"
            continue
        fi
        size=$(du -sk "$dir" 2>/dev/null | cut -f1)
        if rm -rf -- "$dir"; then
            echo "prune: removed $name ($(freed_bytes "$((size * 1024))"))"
            total=$((total + size))
        fi
    done

    local use
    use=$(df -P "$target_root" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    case "$use" in ''|*[!0-9]*) use=0;; esac
    if [ "$use" -gt "$threshold" ]; then
        local inc=$target_root/rust-target/debug/incremental
        if [ -d "$inc" ]; then
            if in_use "$inc"; then
                echo "prune: keep rust-target/debug/incremental (in use)"
            else
                size=$(du -sk "$inc" 2>/dev/null | cut -f1)
                if rm -rf -- "$inc"; then
                    echo "prune: removed rust-target/debug/incremental ($(freed_bytes "$((size * 1024))"))"
                    total=$((total + size))
                fi
            fi
        fi
    fi

    if [ "$total" -gt 0 ]; then
        echo "prune: freed $(freed_bytes "$((total * 1024))") total"
    else
        echo "prune: nothing to remove"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
    . "$here/root.sh"
    prune_targets
fi
