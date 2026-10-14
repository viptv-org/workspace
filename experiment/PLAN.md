# VIPTV v2 experiment

## Destination

One Rust/Crux engine runs inside native applications and on the server. One new KMP application covers Android phone/tablet, Android TV, Windows, Linux, macOS, browser viewing and the dashboard. Native targets have local and remote connections; browser, SolidTV and Roku are remote-only. Android uses Media3 with the official FFmpeg audio extension and hardware video. Desktop uses the pinned KitePlayer fork. Browser/SolidTV/Roku media uses the playback gateway.

The new application is an implementation, not a UI prototype. The final target includes actual provider data, playback, persistence, administration and every applicable current-design state.

## Isolation

Existing experimental worktrees originate from the fetched main revisions in `repositories.json`. Original checkouts, branches, history and production remain separate. Simkl experiments are reference material only. The new application is a new repository on `experiment/kmp-v2`.

## Design

The design repository contains the 197 `current_design` boards from the supplied VIPTV kit. Screenshot IDs, exact HTML, fonts, images and archive hashes are retained. Earlier explorations are absent from the active design tree.

The authoritative visual source is the `VIPTV-screens-1-current-TV.zip` through `VIPTV-screens-4-current-Simkl.zip` archives in the workspace root. The experimental `design/current` import is a byte-matching working copy of those ZIPs; older design-repository material is not a UI reference. The active execution order is exact KMP UI parity across desktop, Android phone/tablet/TV and browser, including native desktop window chrome, followed by logic work. Board-level captures and unresolved surfaces remain tracked in the app repository.

Specific board geometry takes precedence over inconsistent general notes. Conversation architecture takes precedence over old Tauri, web-local-mode and direct Simkl-login assumptions in the kit. Provisional UI is listed individually in the application's `docs/DESIGN_GAPS.md`; the current-board coverage register has a separate status for each board.

## Engine and profiles

The core owns rules, canonical identities, presentation, mappings and playback decisions. Host adapters execute HTTP, SQLite, secure storage and player work. Local mode has one default profile and supports more without a backend. Connection changes isolate profile state and cancel outstanding work.

Plugin code, configured integration connections and per-profile assignments are separate. A profile has one browsing integration, with several Stremio metadata addons allowed inside Stremio mode. Sources, subtitles and mapping providers can aggregate. Simkl is the remote default when configured; Stremio is the local default. Simkl credentials and tracking are profile-specific and server-only, linked through the dashboard.

Initial integrations: Stremio, Simkl, vsources, Xtream, M3U and identity mappings. Search/discovery capabilities describe supported controls and availability. Missing IDs, unverified episode matches and mapping conflicts never silently identify a different episode. Externally executable plugins and Trakt are later extensions.

## Network behavior

Bootstrap returns identity, profiles, capability state and initial prepared Home content. Initial Home has no per-card metadata fetch. Hover/focus uses existing projections; detail opens load detail and paged seasons. Provider requests are coalesced in the engine and caches separate public metadata from profile state. Initial screen assembly has a bounded deadline and does not wait for source discovery, statistics or tracking sync.

Acceptance targets: one initial control request plus at most one pending update connection; interactive shell within 500 ms after app startup; warm Home within one second; useful cold Home within three seconds on the reference fixture whose healthy upstream responds within one second. Slow-provider failure is visible rather than an indefinite blank screen. Real upstream timing is reported separately.

## Playback and application

Playback qualification covers Android API 26+ through Media3 and desktop JVM on Linux/Windows/macOS through KitePlayer, including HTTP headers, VOD, live HLS/DASH/TS, audio/subtitles, seek, switching and cleanup. Local acquisition uses a host adapter. Full local transcoding is outside this experiment.

Application flows include authentication and device linking; profiles/PINs; browsing/search; guide; details/seasons/sources; native/web playback; lists/history; Simkl calendar/filters/tracking; settings; dashboard; desktop window/media features and supported TV control. Playback starts from an explicit action, and the next episode waits for the user.

## Delivery status — 2026-10-14

1. Experimental branches and the new KMP app repository exist; main branches and history remain preserved.
2. The 197 current boards are imported. KMP TV follows the provided layouts; complete board-by-board parity and physical performance acceptance remain unqualified.
3. Native Rust/SQLite profiles, Stremio, native vsources, mappings, Live and local/remote playback are implemented. Broader provider/format/long-running qualification remains incomplete.
4. Backend v3 aggregates, per-profile plugins/capabilities, Simkl OAuth 2.0 metadata/lists/tracking, unified library/continuation and scoped delivery are implemented. The current backend passed 413 checks; this does not certify all end-to-end flows.
5. KMP builds for Android, Web and Linux/Windows/macOS desktop. Normal TV device pairing passed a live adapter approval/restore/Home check. The next candidate remains uninstalled during the user's physical-TV testing.
6. Android hardware 1080p60 with official FFmpeg AAC audio was measured at approximately 60 FPS without decoder drops. UI focus/animation performance, broader seek/subtitle/audio formats, desktop presentation and complete settings/dashboard acceptance remain open.
7. Solid TV-web and Roku use shared host content APIs, automatic paging and provider caption contracts. Full TV-web/Roku design migration and physical decoding remain incomplete.
8. The generic native Tauri video plugin is now `vynxc/tauri-plugin-video`; experimental cleanup retained all history and main. Old desktop/Android host branch trees are retired in favor of KMP; repositories, main branches, history and historical local files are retained.
9. Local QA API, gateway and trusted canonical/LAN HTTPS routes run under enabled user services with automatic restart. Production deployment is not claimed.

Current detailed evidence and unresolved UI are in the app's `docs/STATUS.md`,
`docs/build-evidence.json`, `docs/DESIGN_GAPS.md` and design coverage register.

## Evidence

Verification concentrates on public engine behavior, local/HTTP equivalence, profile isolation, identity, real playback, data migration, network budgets and current-board visual comparison. Duplicated retired-behavior tests and source-text assertions have no role in the new implementation. Generated data is separate from small feature-oriented authored files.

No production rollout, main merge, repository deletion, history rewrite, external plugin marketplace, automatic local/remote synchronization, or native LAN-server feature is part of this experiment.
