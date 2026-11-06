#!/usr/bin/env bash
# Gradle runs in the gates with Kotlin incremental compilation on. A corrupted
# <module>/build/kotlin cache fails a compile with "Incremental compilation
# failed" and no source error, so the gate reports RED for a commit that builds;
# deleting those caches is the fix. gate_gradle builds as usual and, when the log
# shows a cache fault rather than a source error, keeps that log, deletes the
# clone's Kotlin caches and runs the command once more, so the gate reports the
# build's result rather than the cache's. Source this file, then:
#
#   gate_gradle <clone> <log> <command...>
#
# A retry costs a full rebuild (2m02s for a desktop compile, against 1m14s
# incremental), so it only happens when the first build failed. Both attempts
# write through the log path a gate greps afterwards: a retry moves the fault's
# log to <log>-cache-fault.log, and a run that never faults leaves only <log>.
# The test is lib/kotlin-cache.test.sh.

kotlin_cache_fault() {
    local log=$1
    grep -q 'Incremental compilation failed' "$log" 2>/dev/null && return 0
    grep -q 'Kotlin compiler error' "$log" 2>/dev/null && ! grep -q '^e: file:' "$log" 2>/dev/null
}

clear_kotlin_caches() {
    [ -d "$1" ] || return 0
    find "$1" -mindepth 2 -maxdepth 3 -type d -path '*/build/kotlin' -exec rm -rf {} + 2>/dev/null
}

gate_gradle() {
    local clone=$1 log=$2 fault code
    shift 2
    "$@" > "$log" 2>&1
    code=$?
    [ $code = 0 ] && return 0
    kotlin_cache_fault "$log" || return $code
    fault=${log%.log}-cache-fault.log
    mv -f "$log" "$fault"
    echo "gate: Kotlin incremental cache fault (its log is $fault); deleted $clone's build/kotlin caches and retried"
    clear_kotlin_caches "$clone"
    "$@" > "$log" 2>&1
}