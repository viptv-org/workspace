#!/usr/bin/env bash
# Batch gate for viptv-org/app main (/work step 5): run the full suite once;
# green -> tag good/<date>-<n>, then the private post-merge steps (dev-instance
# APK build and TV emulator install via the ignored .kmp-dev tooling).
set -o pipefail
root=$(cd "$(dirname "$0")/../.." && pwd); app=$root/app
cd $app && git checkout -q main && git pull -q --ff-only && git submodule update -q --init native/core || exit 2
rev=$(git rev-parse --short HEAD)
export RUSTUP_TOOLCHAIN=1.98.0 JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 LC_ALL=C VIPTV_PLAYBACK_GATEWAY=$root/playback-gateway
echo "gate $rev: desktopTest"
"$root/scripts/agents/heavy.sh" ./gradlew --max-workers=1 -Dorg.gradle.daemon.idletimeout=900000 :composeApp:desktopTest > /tmp/batch-gate-test.log 2>&1
code=$?
APP=$app python3 - <<'PY'
import glob,os,xml.etree.ElementTree as E
t=f=0;fl=[]
for p in glob.glob(os.environ['APP']+'/composeApp/build/test-results/desktopTest/*.xml'):
    r=E.parse(p).getroot();t+=int(r.get('tests'));n=int(r.get('failures'))+int(r.get('errors'));f+=n
    if n:fl.append(r.get('name'))
print(f"tests={t} failed={f} {fl}")
PY
[ $code = 0 ] || { echo "RED $rev"; exit 1; }
n=$(( $(git tag -l "good/$(date -u +%F)-*" | wc -l) + 1 )); tag=good/$(date -u +%F)-$n
git tag -a $tag -m "Green batch: desktopTest passed at $rev" && git push -q origin $tag && echo "GREEN $rev tagged $tag"
cd $root && export RUSTUP_TOOLCHAIN=1.98
scripts/agents/heavy.sh bash .kmp-dev/kmp.sh build apk > /tmp/batch-gate-apk.log 2>&1 || { echo "APK build failed"; exit 3; }
flock /tmp/viptv-emulator.lock bash .kmp-dev/kmp.sh install-apk emulator-5580 > /tmp/batch-gate-install.log 2>&1 && echo "TV installed $(readlink ~/.local/state/viptv-kmp/apk/latest.apk)"
