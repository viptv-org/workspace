#!/usr/bin/env bash
# Batch gate for viptv-org/app (/work step 5). PRs merge unbuilt into edge;
# this runs the full suite, the web compile and the release APK once on edge.
# Green -> tag good/<date>-<n>, promote edge to main (fast-forward, closing the
# promoted PRs' issues), then the private post-merge steps (TV emulator install
# and the update feed via the ignored .kmp-dev tooling). Red -> main is untouched.
set -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd); app=$root/app
branch=${GATE_BRANCH:-edge}
cd $app && git fetch -q origin && git checkout -q "$branch" && git pull -q --ff-only && git submodule update -q --init native/core || exit 2
sha=$(git rev-parse HEAD); rev=${sha:0:7}
export RUSTUP_TOOLCHAIN=1.98.0 JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 LC_ALL=C VIPTV_PLAYBACK_GATEWAY=$root/playback-gateway
echo "gate $branch $rev: desktopTest + compileKotlinWasmJs"
"$root/scripts/agents/heavy.sh" ./gradlew --max-workers=1 -Dorg.gradle.daemon.idletimeout=900000 :composeApp:desktopTest :composeApp:compileKotlinWasmJs > /tmp/batch-gate-test.log 2>&1
code=$?
APP=$app python3 - <<'PY'
import glob,os,xml.etree.ElementTree as E
t=f=0;fl=[]
for p in glob.glob(os.environ['APP']+'/composeApp/build/test-results/desktopTest/*.xml'):
    r=E.parse(p).getroot();t+=int(r.get('tests'));n=int(r.get('failures'))+int(r.get('errors'));f+=n
    if n:fl.append(r.get('name'))
print(f"tests={t} failed={f} {fl}")
PY
[ $code = 0 ] || { echo "RED $rev: desktopTest or web compile failed (see /tmp/batch-gate-test.log)"; exit 1; }
cd $root && export RUSTUP_TOOLCHAIN=1.98
scripts/agents/heavy.sh bash .kmp-dev/kmp.sh build apk > /tmp/batch-gate-apk.log 2>&1 || { echo "RED $rev: APK build failed (see /tmp/batch-gate-apk.log)"; exit 3; }
# Tag and promote only once the suite, the web compile AND the release APK pass.
cd $app
n=$(( $(git tag -l "good/$(date -u +%F)-*" | wc -l) + 1 )); tag=good/$(date -u +%F)-$n
git tag -a $tag -m "Green batch: desktopTest, web compile and APK passed at $rev" "$sha" && git push -q origin $tag && echo "GREEN $rev tagged $tag"
"$root/scripts/agents/promote.sh" app "$sha" "$tag" || echo "Promote failed: main not moved"
git checkout -q main && git pull -q --ff-only
cd $root
flock /tmp/viptv-emulator.lock bash .kmp-dev/kmp.sh install-apk emulator-5580 > /tmp/batch-gate-install.log 2>&1 && echo "TV installed $(readlink ~/.local/state/viptv-kmp/apk/latest.apk)" || echo "TV install failed: $(tail -1 /tmp/batch-gate-install.log) (systemctl --user is-active serve-avd-emulator.service)"
bash .kmp-dev/kmp.sh publish-update > /tmp/batch-gate-publish.log 2>&1 && echo "Published update feed: $(tail -1 /tmp/batch-gate-publish.log)" || echo "Publish failed: see /tmp/batch-gate-publish.log"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 RUSTUP_TOOLCHAIN=1.98.0
scripts/agents/heavy.sh bash .kmp-dev/kmp.sh build web > /tmp/batch-gate-web.log 2>&1 && echo "Web app rebuilt from main" || echo "Web build failed: see /tmp/batch-gate-web.log"
