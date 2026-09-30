# Portable engineering handoff

Resume from [the integration handoff map](https://github.com/viptv-org/workspace/issues/2).
It links the owning web, gateway, Android and TV-web tickets and records the
remaining decisions and acceptance. [Workspace PR](https://github.com/viptv-org/workspace/pull/1)
packages these instructions and the portable bundle.

## Current authorization

The owner allows UI changes across affected clients, including Android, as of
2026-09-30. This supersedes the earlier backend/logic-only restriction. Read the
updated handoff map and owning ticket; specify affected screens, states, focus,
loading/error and return flows in design before changing them, then adopt the
immutable design revision. Merge, deployment and destructive migration still
require separate approval.

The permission amendment is published in [design PR 9](https://github.com/viptv-org/design/pull/9)
at `bbae06df0840c0e5fb17eb0cc59f6d846d3c63a7`; this is a documentation-only draft,
not an automatic app pin update or new rendered-UI evidence.

Android ownership correction: the owner made no separate Android UI changes.
All eight dirty files in the original checkout exactly match committed Core-sync
work in Android `02b70ae`, already included on the published cutover branch.
There are no uncommitted app/UI or untracked files in that checkout at verification.
Recheck status before reconciling branches; preserve the reviewed candidate work.

Start with [the implementation ledger](https://github.com/viptv-org/design/blob/main/IMPLEMENTATION_V2.md)
and the owning GitHub ticket. They distinguish implementation, actual evidence
and remaining acceptance; a passing build is not deployment or device proof.

Review checkpoints from the paused work:

| Repository | Review branch / checkpoint | Remaining work |
| --- | --- | --- |
| playback-gateway | `refactor/shared-ingest`, `fb15c39` | Progressive original-container fanout; subtitle active-cue carryover; remaining codecs. AV checkpoint has 104 default tests and documented exact-image evidence. |
| android | `refactor/android-backend-cutover`, `14bc969` | UI work is allowed; preserve frozen wire and reviewed candidate work. No independent owner UI edits were found. |
| backend | `refactor/backend-v2`, `b78aab2` (runtime `27a0296`) | Current-data rollback evidence is in the owning operations docs; reverse VOD cursors remain missing. |
| web | `refactor/admin-v2`, `93c9316`; WIP `fix/admin-bounded-vod`, `202aaeb` | [Draft PR 3](https://github.com/viptv-org/web/pull/3) is unverified and depends on missing reverse cursors; [ticket 5](https://github.com/viptv-org/web/issues/5) owns the vertical slice. |
| android stress | `test/android-native-core-stress`, `85adc70` | Tests-only native/JNI checkpoint, not foreground-media or physical-device qualification; distribute the normal cutover APK, never the fixture APK. |

Resolve branch tips and ticket status before resuming; these are review
checkpoints, not automatic merge/deploy authority. Preserve unrelated edits.
Gateway progressive code was not written and has no hidden WIP. Remaining
acceptance belongs in owning tickets, not an implied completed universal gate.

The vendored `.agents/skills` and `skills-lock.json` are the exact installed
bundle. Run `bash scripts/install-agent-skills.sh [workspace-directory]` to add
missing skills. Existing folders/lockfiles/config/AGENTS remain untouched;
review differing local versions explicitly rather than overwriting them.
