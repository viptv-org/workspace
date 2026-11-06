#!/usr/bin/env bash
# Checks the gates' Kotlin cache recovery (lib/kotlin-cache.sh): a build that
# fails on the incremental cache is retried once with the clone's build/kotlin
# deleted and the retry's result is the gate's result, a real compile error is
# reported once with its caches kept, other build output survives the clear, and
# every gradle run a gate makes goes through gate_gradle.
set -uo pipefail
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

clone=$tmp/app
cache=$clone/composeApp/build/kotlin/compileTestKotlinDesktop
plant() {   # the caches a corrupted run leaves behind, beside output it must not touch
    mkdir -p "$cache/caches-jvm" "$clone/androidApp/build/kotlin/compileAndroidMain" \
        "$clone/composeApp/build/classes/kotlin/desktopTest" "$clone/native/core/build"
    echo stale > "$cache/caches-jvm/lookups"
    echo stale > "$clone/androidApp/build/kotlin/compileAndroidMain/last-build-info"
    echo kept > "$clone/composeApp/build/classes/kotlin/desktopTest/Kept.class"
}
plant

# A stand-in for ./gradlew. cache is the failure this is about: the compiler
# reports the cache fault and no source error for as long as build/kotlin is
# there, and the build is green once it is gone. cache-stuck keeps failing, and
# compiler-error is the same fault as the compiler prints it inside Gradle's
# failure block.
cat > "$tmp/gradlew" <<'GRADLE'
#!/usr/bin/env bash
attempts=$(( $(cat "$FAKE_ATTEMPTS" 2>/dev/null || echo 0) + 1 ))
echo "$attempts" > "$FAKE_ATTEMPTS"
echo "attempt $attempts: gradlew $*"
fault() {
    echo "e: Incremental compilation failed: The following FqNames can't be derived from DirtyData.dirtyLookupSymbols: org.viptv.app.player.mpv.MpvNative."
    echo "* What went wrong:"
    echo "  > Kotlin compiler error"
    echo "BUILD FAILED"
}
cached() { [ -d "$FAKE_CLONE/composeApp/build/kotlin" ]; }
case $FAKE_MODE in
    cache) cached && { fault; exit 1; }; echo "BUILD SUCCESSFUL"; exit 0 ;;
    cache-stuck) fault; exit 1 ;;
    compiler-error)
        cached || { echo "BUILD SUCCESSFUL"; exit 0; }
        echo "* What went wrong:"
        echo "  > Kotlin compiler error"
        echo "BUILD FAILED"
        exit 1 ;;
    source)
        echo "e: file:///src/commonMain/kotlin/Broken.kt:3:1 unresolved reference: nope"
        echo "* What went wrong:"
        echo "  > Kotlin compiler error"
        echo "BUILD FAILED"
        exit 1 ;;
    broken) echo "BUILD FAILED"; exit 1 ;;
    *) echo "BUILD SUCCESSFUL"; exit 0 ;;
esac
GRADLE
chmod +x "$tmp/gradlew"

# run_gate <mode>: runs the lib's gate_gradle the way a gate does, in the fake
# clone with the fake gradle; leaves its exit code in $code.
run_gate() {
    rm -f "$tmp/attempts" "$tmp/desktopTest.log" "$tmp/desktopTest-cache-fault.log"
    FAKE_MODE=$1 FAKE_ATTEMPTS=$tmp/attempts FAKE_CLONE=$clone \
        bash -c '. "$1/kotlin-cache.sh"; shift; gate_gradle "$@"' \
        _ "$here" "$clone" "$tmp/desktopTest.log" "$tmp/gradlew" --max-workers=1 \
        > "$tmp/gate.out" 2>&1
    code=$?
}
attempts() { cat "$tmp/attempts" 2>/dev/null || echo 0; }

echo "a cache fault is retried with the Kotlin caches deleted:"
run_gate cache
[ "$code" = 0 ] || fail "a cache fault still failed the gate: exit $code $(cat "$tmp/gate.out")"
[ "$(attempts)" = 2 ] || fail "the cache fault ran the build $(attempts) time(s), expected 2"
grep -q 'cache fault' "$tmp/gate.out" || fail "the gate did not say it retried: $(cat "$tmp/gate.out")"
grep -q 'build/kotlin' "$tmp/gate.out" || fail "the gate did not say what it deleted"
grep -q 'Incremental compilation failed' "$tmp/desktopTest-cache-fault.log" ||
    fail "the fault's log was not kept"
grep -q 'BUILD SUCCESSFUL' "$tmp/desktopTest.log" || fail "the retry's log is not the gate's log"
grep -q 'Incremental compilation failed' "$tmp/desktopTest.log" &&
    fail "the gate's log still carries the cache fault"
[ -d "$clone/composeApp/build/kotlin" ] && fail "composeApp's build/kotlin survived the retry"
[ -d "$clone/androidApp/build/kotlin" ] && fail "androidApp's build/kotlin survived the retry"
[ -f "$clone/composeApp/build/classes/kotlin/desktopTest/Kept.class" ] ||
    fail "the retry deleted build/classes as well as build/kotlin"
[ -d "$clone/native/core/build" ] || fail "the retry deleted a native/ build directory"
echo "  attempts $(attempts), retried and green"

echo "a compiler error without a source error is the same fault:"
plant
run_gate compiler-error
[ "$code" = 0 ] || fail "a compiler error without a source error failed the gate: exit $code"
[ "$(attempts)" = 2 ] || fail "it ran the build $(attempts) time(s), expected 2"
echo "  attempts $(attempts), retried and green"

echo "a real compile error is reported once and keeps its caches:"
plant
run_gate source
[ "$code" = 1 ] || fail "a source error exited $code, expected 1"
[ "$(attempts)" = 1 ] || fail "a source error ran the build $(attempts) time(s), expected 1"
grep -q 'unresolved reference' "$tmp/desktopTest.log" || fail "the source error is not in the gate's log"
[ -d "$clone/composeApp/build/kotlin" ] || fail "a source error deleted the Kotlin caches"
[ -e "$tmp/desktopTest-cache-fault.log" ] && fail "a source error kept a fault log"
echo "  attempts $(attempts), RED with its caches"

echo "a failure without a compiler error is not retried:"
plant
run_gate broken
[ "$code" = 1 ] || fail "an unrelated failure exited $code, expected 1"
[ "$(attempts)" = 1 ] || fail "an unrelated failure ran the build $(attempts) time(s), expected 1"
echo "  attempts $(attempts)"

echo "a clean build runs once:"
run_gate ok
[ "$code" = 0 ] || fail "a clean build exited $code"
[ "$(attempts)" = 1 ] || fail "a clean build ran $(attempts) time(s), expected 1"
echo "  attempts $(attempts)"

echo "a fault that survives the cache clear is not retried forever:"
run_gate cache-stuck
[ "$code" = 1 ] || fail "an unfixable cache fault exited $code, expected 1"
[ "$(attempts)" = 2 ] || fail "an unfixable cache fault ran the build $(attempts) time(s), expected 2"
echo "  attempts $(attempts), RED"

echo "every gradle run in a gate goes through gate_gradle:"
for gate in "$here"/../*-batch-gate.sh; do
    name=$(basename "$gate")
    runs=$(grep -v '^[[:space:]]*#' "$gate" | grep -cE 'gradlew|kmp\.sh build ')
    [ "$runs" -gt 0 ] || continue
    grep -q 'lib/kotlin-cache.sh' "$gate" || fail "$name does not source lib/kotlin-cache.sh"
    through=$(grep -v '^[[:space:]]*#' "$gate" | grep -c 'gate_gradle ')
    [ "$through" = "$runs" ] ||
        fail "$name runs gradle $runs time(s) but gate_gradle $through time(s)"
    echo "  $name: $runs gradle run(s), all through gate_gradle"
done

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
fi
echo "PASS"