# Portable engineering handoff

Resume from [the integration handoff map](https://github.com/viptv-org/workspace/issues/2).
It is the single live record of branch tips, owning tickets, remaining decisions
and acceptance; this page does not duplicate it, so resolve current branch tips
and ticket status there before resuming. The
[implementation ledger](https://github.com/viptv-org/design/blob/main/IMPLEMENTATION_V2.md)
separates implementation from actual evidence; a passing build is not deployment
or device proof.

## Current state (2026-09-30)

UI changes are allowed across affected clients, including Android, provided the
affected screens and states are specified in design first; the
[VIPTV Redesign canvas](https://claude.ai/artifact/UX1E5AtPUoSKnaSLPou3Pp) and
`design/viptv-design-system/` are the visual source. That scope amendment and the
bounded admin VOD (ADM-002-VOD-WINDOW) and Android foreground (AND-041)
specifications are merged to design `main`. The gateway shared SubRip replay
slice (playback-gateway issue 2) and the narrow Android foreground/media slice
(android issue 4) are qualified for their documented scope only. Decision
recorded 2026-09-30 on playback-gateway issue 1: original progressive delivery is
same-container lossless remux; that ticket is ready for implementation.
TV-web signing and target hardware need device access, and native/physical-device,
rollback and integration gates remain open. Agents may merge reviewed PRs to
`main` (decision recorded 2026-09-30); deployment and destructive migration still
need separate approval. Preserve unrelated and original checkout edits.

## Skill bundle

The vendored `.agents/skills` and `skills-lock.json` are the exact installed
bundle. Run `bash scripts/install-agent-skills.sh [workspace-directory]` to add
missing skills. Existing folders/lockfiles/config/AGENTS remain untouched;
review differing local versions explicitly rather than overwriting them.
