# KMP: bringing the full avatar catalog into the Kotlin Multiplatform app

Research date: 2026-10-18. Scope: identify the "account builder" avatar catalog
that already ships on the other clients, confirm where it is merged, and map
what the Kotlin Multiplatform (KMP) app plus its backend branch need so the
same catalog lands on `experiment/kmp-v2`. These are implementation findings,
not an approved UI specification.

## What the catalog is

The large icon picker is the **profile avatar catalog**, specified for the
account dashboard as **ADM-004** in `design/plans/backend-v2/ADMIN_V2.md`
(design commit `01341d3`, already on design `main`). Android and Roku shipped
it first; the dashboard (`web`) and the TV web client (`tv-web`) followed.

The single source of truth is in the `design` repository:

| Asset | Path (under `design/assets/roku/roku/`) | Contents |
| --- | --- | --- |
| Catalog | `data/avatar-catalog.json` | 16 worlds, `per_category: 48`, `total: 624` |
| Provenance | `data/character-avatars.json` | Names and sources for the character worlds |
| Generated art | `images/avatar-catalog/` | 576 PNGs, 12 DiceBear styles x 48, CC0, 3.6 MB |
| Character art | `images/avatar-characters/` | 48 curated Disney PNGs, 2.0 MB, rights stay with holders |

Worlds, in catalog order: Disney favorites (14), Princesses (10), Animal
friends (12), Villains (12), then Creatures, Robots, Block bots, Pixel heroes,
Pixel pals, Sprouts, Space, Clay friends, Moods, Thumb buddies, People, Doodles
(48 each). The four character worlds carry an explicit `items` list with a
`local` path such as `pkg:/images/avatar-characters/disney-1.png`; generated
worlds have no `items` and resolve to `avatar-catalog/{style}-{n}.png`.

A selection is persisted as `avatar_style` plus a 1-based `avatar_choice`;
the backend stores it as the seed `viptv-{style}-{choice}`. Positions are
stable and append-only; never reorder a published world.

## Merge status per repository

| Repo | State on 2026-10-18 | Evidence |
| --- | --- | --- |
| `design` | ADM-004 merged to `main`; `spec/web-avatar-catalog` has nothing left to merge | `git log main..spec/web-avatar-catalog` is empty |
| `web` | Merged; `main` HEAD is `d2d5b27` "Offer the full design avatar catalog in the account dashboard"; `feat/full-avatar-catalog` equals `main` | 627 avatar files tracked under `public/avatars/` and `design-contract/` |
| `tv-web` | Merged; `main` HEAD is `f109eb3` "Offer the full design avatar catalog on web" | `src/ui/avatarCatalog.ts` reads the pinned catalog directly |
| `android` | Full catalog since `0428838` (2026-09-12); assets committed under `app/src/androidMain/assets/roku/` | `AccountScreens.kt` `avatarCatalog()` and `AvatarPicker` |
| `roku` | Native owner of the catalog | `design/assets/roku/...` mirrors it |
| `backend` | Account profile API already stores and validates the catalog on both `main` and `experiment/kmp-v2` | `server/src/auth/avatars.rs`, bundled `server/assets/character-avatars.json` |
| `app` (KMP) | **Not done.** Four hard-coded avatars | see next section |

So nothing remains to merge into `main` for web, tv-web, design or android.
The remaining work is entirely on the KMP side: the `app` repository (default
branch `experiment/kmp-v2`) and the backend `experiment/kmp-v2` branch that
serves it. The backend branch is 59 commits ahead of `main` and 0 behind, so
it contains everything `main` has.

## The KMP gap

The KMP app has a provisional picker recorded as **GAP-011** and **GAP-027** in
`app/docs/DESIGN_GAPS.md`. The current implementation:

- `composeApp/src/commonMain/kotlin/org/viptv/app/features/entry/AvatarPicker.kt`
  is an `AlertDialog` with four fixed ids: `vynxc`, `zayne`, `initial-pink`,
  `initial-blue`. It is reused by `ProfileEditScreen.kt` (desktop),
  `MobileProfileEdit.kt` (phone) and `TvProfileEditScreen.kt` (TV).
- `features/entry/ProfileAvatar.kt` maps `vynxc`/`zayne` to two bundled
  drawables (`composeResources/drawable/avatar_*.png`), two ids to flat colours,
  otherwise a remote `profile.avatar` URL via Coil 3 `AsyncImage`, otherwise an
  initial letter.
- `connection/RemoteConnection.kt` `Profile` carries only `avatarId`;
  `connection/RemoteProfiles.kt` parses `avatar_id` and PATCHes
  `/api/profiles/{id}` with `{"avatar_id": ...}`. The bootstrap `avatar_ids`
  list from the server is parsed but never used by the picker.
- `state/ControllerProfiles.kt` `setProfileAvatar` routes to either the local
  engine or the remote connection with the same id string.
- Local engine: `native/core/crates/viptv-engine/src/store/profiles.rs`
  `set_profile_avatar` rejects anything outside the same four ids;
  `viptv-core/src/local_engine/profiles.rs` and the generated
  `ProfileConfiguration.avatar_id` in `org/viptv/engine/wire/EngineWire.kt`
  carry it through.

On the backend `experiment/kmp-v2` branch, the KMP engine route is a separate
layer over the account profiles:

- `server/src/engine_v3/profiles.rs` keeps `const AVATARS` with the same four
  ids, stores the choice in its own `engine_profile_presentation` table
  (commits `f116ea4`, `88afbc8`, both kmp-v2 only), and its `project()` emits
  `avatar_id` while dropping the account record's `avatar_style`,
  `avatar_choice` and `avatar_url`.
- The underlying `auth::update_profile` / `profile_json` already validate
  `avatar_style` against `AVATAR_STYLES`, bound `avatar_choice` to the world's
  size, and compute `avatar_url` (DiceBear URL or the Disney CDN URL).

Result: a profile created in the account dashboard with a catalog avatar shows
up in the KMP app as a coloured initial, and an avatar chosen in the KMP app is
invisible to every other client.

## Related branch facts that affect the KMP cutover

- The kmp-v2 backend pins its `dashboard` submodule to web `a2474b7`, two
  commits behind web `main`, so the dev instance's dashboard still shows the
  seven generated style previews. Bumping the submodule to `d2d5b27` picks up
  ADM-004 without conflicts because the submodule tracks the `main` lineage.
- Web has a separate `experiment/kmp-v2` branch whose only extra commit
  `54dccd9` deletes `DESIGN_REF`, `design-contract/ADMIN_V2.md`,
  `design-contract/BACKEND_V2.md` and `scripts/design-sync.mjs`. Merging web
  `main` into it produces four modify/delete conflicts. That branch is not what
  the backend submodule uses, so it can be left alone or retired.
- `.kmp-dev/kmp.sh` `stage_web` copies only the dashboard's hashed `assets/`
  directory next to the KMP wasm build. The dashboard's catalog lives under
  `dist/avatars/`, so that staging step needs to copy `avatars/` too (or the
  backend's `ServeDir` must serve the dashboard dist directly).
- The app's supplied design boards (197, under `.worktrees/kmp-v2/design/current`
  per `docs/AGENT_HANDOFF_2026-10-14.md`) are not present on this VPS. They
  include an Edit profile board with "Change avatar" but no picker board, which
  is why GAP-027 exists. The Android `AvatarPicker` ("Find your favorite",
  world chips, 3-column phone / 6-column TV grid, 15 or 18 per page,
  Previous/Next) is the de facto reference and matches ADM-004's paging rules.
- The app's local checkout is on `feature/kmp-stremio-import`, two commits
  ahead of `experiment/kmp-v2`; the backend worktree is on the matching
  `feature/kmp-stremio-import`, one commit ahead. Avatar work should branch
  from `experiment/kmp-v2` after those land, or stack on top of them.

## Recommended implementation shape

Ordered so each step is independently testable.

1. **Backend `experiment/kmp-v2`: expose the catalog through the engine route.**
   In `engine_v3/profiles.rs`, accept `avatar_style` + `avatar_choice` in create
   and update by delegating to `auth::update_profile` (which already validates),
   and make `project()` pass through `avatar_style`, `avatar_choice` and
   `avatar_url` from `auth::list_profiles`. Retire `AVATARS` and the
   `engine_profile_presentation` table, or keep `avatar_id` as a read-only
   legacy field for the two existing bundled ids until the app no longer sends
   it. Update `engine_v3/profile_tests.rs`, `auth_integration_tests.rs`,
   `tests/auth_http_flow.rs` and `routes.rs` fixtures that mention `vynxc`.
   Also bump the `dashboard` submodule to web `d2d5b27` and extend
   `kmp.sh stage_web` to copy `avatars/`.
2. **App: ship the catalog as Compose resources.** Add
   `composeApp/src/commonMain/composeResources/files/avatars/avatar-catalog.json`
   plus the 624 PNGs (about 5.6 MB). Compose Multiplatform serves `files/` by
   URI (`Res.getUri`) on every target and the wasm distribution fetches them
   individually on demand, so the browser bundle does not grow; the Android APK
   grows by the asset size, as the Android client already accepted. Coil 3 is
   already in `commonMain` and loads those URIs. Record the source pin (design
   commit) the way `android/DESIGN_REF` does so the copy can be verified.
3. **App: one catalog module.** Add `features/entry/AvatarCatalog.kt` in
   `commonMain` mirroring tv-web `avatarCatalog.ts` and Android
   `avatarCatalog()`: parse the JSON once, expose worlds with counts, the total,
   `avatarUri(style, choice)` and `profileAvatarChoice(profile)` with the
   backend defaults (`critters`, 1).
4. **App: model and transport.** Extend `Profile` with `avatarStyle`,
   `avatarChoice` and `avatarUrl`; parse them in `RemoteConnection.kt` and
   `RemoteProfiles.kt`; send `avatar_style` and `avatar_choice` on PATCH. For
   the local engine, replace the four-id allow-list in
   `viptv-engine/src/store/profiles.rs` with style/choice storage validated
   against the bundled catalog (or a style allow-list plus a 1..48 bound), then
   regenerate bindings per `app/tools/build_engine.py` so `ProfileConfiguration`
   carries the new fields. Update `viptv-engine/tests/profiles.rs` and
   `viptv-core/tests/contract.rs`.
5. **App: picker and rendering.** Replace `AvatarPicker.kt` with a world-chip
   row plus paged grid (15 per page on phone, 18 on TV and desktop), wrap-around
   Previous/Next, "[N] avatars. Pick a world, then pick your character." copy,
   and a check badge on the saved choice; keep the existing PIN gate for local
   locked profiles. On TV, give the grid D-pad focus and restore focus to
   "Change avatar" on close, as `TvProfileEditScreen.kt` already does.
   `ProfileAvatar.kt` resolves style/choice to the packaged image first, then
   `avatarUrl`, then the initial. Update `ProfileAdministrationUiTest.kt`,
   `RemoteProfilesTest.kt` and `preview/PreviewData.kt`, and replace the
   `docs/DESIGN_GAPS.md` GAP-011 entry with the new evidence capture.
6. **Verification.** `kmp.sh build all` on the dev instance, the desktop test
   gate, the Android emulator check from the serve-avd workflow, and a
   round-trip: choose an avatar in the dashboard, confirm it in the KMP TV and
   phone builds, then the reverse.

## Decisions for the owner

- **Bundle or fetch?** Bundling (step 2) keeps local-engine profiles working
  offline and matches Android. The alternative, loading
  `/avatars/avatar-catalog/...` from the connected server, needs no app assets
  but fails for native local mode and depends on the staging fix in step 1.
- **Legacy ids.** Profiles on the kmp dev instance may already hold `vynxc` or
  `zayne` in `engine_profile_presentation`. Either keep rendering those two
  bundled drawables for the transition or clear them on migration.
- **Disney artwork.** The 48 character thumbnails are not CC0. Android, web
  and Roku already ship them; shipping them in the KMP binaries is the same
  exposure, but it is a conscious choice.

## Sources

- `design/plans/backend-v2/ADMIN_V2.md` (ADM-004), `design/assets/ASSET_MANIFEST.md`,
  `design/assets/roku/roku/images/avatar-catalog/README.md`,
  `design/assets/roku/roku/images/avatar-characters/README.md`
- `tv-web/src/ui/avatarCatalog.ts`; web commit `d2d5b27`; tv-web commit `f109eb3`
- `android/app/src/androidMain/kotlin/org/viptv/app/AccountScreens.kt`
- `app/composeApp/src/commonMain/kotlin/org/viptv/app/features/entry/{AvatarPicker,ProfileAvatar}.kt`,
  `app/composeApp/src/commonMain/kotlin/org/viptv/app/connection/{RemoteConnection,RemoteProfiles}.kt`,
  `app/native/core/crates/viptv-engine/src/store/profiles.rs`, `app/docs/DESIGN_GAPS.md`
- `.worktrees/kmp-v2/backend/server/src/engine_v3/profiles.rs`,
  `.worktrees/kmp-v2/backend/server/src/auth/avatars.rs`, `.kmp-dev/kmp.sh`
