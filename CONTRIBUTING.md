# Contributing to VIPTV

1. Start from this repository: `./setup.sh` gives you the full workspace in
   the canonical layout, and `./run.sh <repo>` wraps each repository's check
   commands.
2. Product behavior changes start in `design`: read the pinned `DESIGN_REF`,
   record the proposed UX change there first, and link the approved design
   commit in the implementation ticket.
3. Implement in the **owning** repository (see the map in
   [AGENTS.md](AGENTS.md)). Update consumers only when the contract changes.
4. Run the repository's checks before pushing. Per-repo guides:
   - `video/CONTRIBUTING.md`
   - `tauri-video-plugin/CONTRIBUTING.md`
   - every repository's own `AGENTS.md` and `SPEC.md`
5. Specs and tickets live in each repository's GitHub Issues; search existing
   issues before opening a new one.
6. Commit and push inside the owning repository. Changes to the workspace
   notes themselves — this repo's tracked files — are committed here.
7. Never commit secrets: passwords, tokens, API keys, private addresses,
   certificates, `.env` contents, or provider URLs. Device values stay in
   the ignored root `.env`.
8. Report verification honestly: separate what you ran from what you did not
   (hardware, deployment), and never claim a deploy is live without checking
   the served asset hash (see [AGENTS.md](AGENTS.md)).
