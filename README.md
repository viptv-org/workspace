# VIPTV experimental workspace

The `experiment/kmp-v2` branches start from the revisions in `experiment/repositories.json`.
Each repository retains its original history and main branch. Existing Simkl experiments are reference implementations, not ancestry.

| Repository | Contents |
| --- | --- |
| core | Shared Rust/Crux engine, contracts and bindings |
| backend | Authenticated remote host and gateway coordination |
| app | New KMP application, native and remote-only browser targets |
| design | The 197 supplied current boards and assets |
| tv-web / roku | Existing remote clients |
| playback-gateway | Media ingestion, delivery and conversion |

`experiment/cleanup.json` inventories removed repository-local instructions and third-party skills.
The original roots and unrelated worktrees remain intact. Private environment files and production data are outside this experiment.
