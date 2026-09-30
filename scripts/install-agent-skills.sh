#!/usr/bin/env bash
# Install the vendored bundle additively; existing skill/config files win.
set -eu
repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$#" -gt 0 ]; then
    destination=$(CDPATH='' cd -- "$1" && pwd)
elif [ -d "$repo/../design" ] && [ ! -d "$repo/design" ]; then
    destination=$(CDPATH='' cd -- "$repo/.." && pwd)
else
    destination=$repo
fi
mkdir -p "$destination/.agents/skills"
for source in "$repo"/.agents/skills/*; do
    name=${source##*/}
    target="$destination/.agents/skills/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        printf 'preserved existing skill: %s\n' "$name"
    else
        cp -R "$source" "$target"
        printf 'installed skill: %s\n' "$name"
    fi
done
if [ ! -e "$destination/skills-lock.json" ] && [ ! -L "$destination/skills-lock.json" ]; then
    cp "$repo/skills-lock.json" "$destination/skills-lock.json"
fi
printf 'Existing AGENTS.md, agent configuration and lockfiles were preserved.\n'
