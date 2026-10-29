# VIPTV workspace

One clone gives you the whole organization.

```sh
git clone https://github.com/viptv-org/workspace.git
cd workspace
./setup.sh            # clone every org repository into this root
./update.sh           # fast-forward this repo and every clone
./run.sh app          # one repository's checks (app, backend, core, design, playback-gateway, all)
```

Prerequisites are in [docs/platform-deps.md](docs/platform-deps.md).
`playback-gateway` needs separate access; without it the scripts skip it. On
Windows use Git Bash or WSL2.

Each subdirectory is its own repository: commit and push inside the one you
change. [AGENTS.md](AGENTS.md) has the repository map, checks, workflow and
safety rules.
