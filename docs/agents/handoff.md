# Portable engineering handoff

Start with [the implementation ledger](https://github.com/viptv-org/design/blob/main/IMPLEMENTATION_V2.md)
and the owning GitHub ticket. They distinguish implementation, actual evidence
and remaining acceptance; a passing build is not deployment or device proof.

Review checkpoints from the paused work:

| Repository | Review branch / checkpoint | Remaining work |
| --- | --- | --- |
| playback-gateway | `refactor/shared-ingest`, `fb15c39` | Progressive original-container fanout; subtitle active-cue carryover; remaining codecs. AV checkpoint has 104 default tests and documented exact-image evidence. |
| android | `refactor/android-backend-cutover`, `14bc969` | Preserve frozen wire and owner's independent UI work; consult current artifact/emulator ledger. |
| backend | `refactor/backend-v2`; rollback rehearsal `5107ca7` | Consult current cursor/browser/media evidence and compatible current-data rollback boundary. |

Resolve branch tips and ticket status before resuming; these are review
checkpoints, not automatic merge/deploy authority. Preserve unrelated edits.
Gateway progressive code was not written and has no hidden WIP. Remaining
acceptance belongs in owning tickets, not an implied completed universal gate.

The vendored `.agents/skills` and `skills-lock.json` are the exact installed
bundle. Run `bash scripts/install-agent-skills.sh [workspace-directory]` to add
missing skills. Existing folders/lockfiles/config/AGENTS remain untouched;
review differing local versions explicitly rather than overwriting them.
