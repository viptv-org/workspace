# Episode intro/outro markers and filler research

Research date: 2026-10-07. Status: recommendation, not an adopted product specification or implemented feature. Scope: every source supplied by the owner, the relevant VIPTV ownership boundaries, and additional filler candidates. Primary-source inspection establishes documented capabilities; it does not establish production uptime, accuracy, or comparative catalog coverage.

## Recommendation

Follow-on deliverable: [proposed implementation plan](https://github.com/viptv-org/design/blob/main/plans/episode-annotations/PLAN.md), including phased repo ownership, normalized reads, cache/worker budgets, interaction requirements and acceptance gates.

Build a native VIPTV feature with replaceable backend data-source adapters. Start with anime timestamp lookup and filler labels, then general-TV timestamps after a representative catalog pilot. Keep automatic media analysis optional and asynchronous. Do not require a browser extension or a third-party streaming scraper to make this feature work.

My recommended first pilot is **AniSkip for anime opening/ending/recap intervals**, **TheIntroDB for general TV/movie segments**, and **Jikan/MAL for positive episode filler/recap annotations**. Add **Anime Skip** when its richer segmentation justifies the more involved identity join. Use **Fribb** to help resolve anime IDs, subject to data-license clarification. Evaluate **AniLiberty** only for releases with verified episode/edition correspondence. This ranking is based on suitability and integration cost, not measured superiority in coverage.

Supporting investigations: [anime timing sources](anime-skip-sources.md), [general timing and detection sources](general-skip-sources.md), and [other anime sources and filler](other-anime-sources.md). The comparison covers the organization links and SDK/extension links together with their underlying service; those links are not independent datasets.

## Every supplied source: capabilities and tradeoffs

| Source | What it actually contributes | Upsides for VIPTV | Downsides / limits | Decision |
| --- | --- | --- | --- | --- |
| [AniSkip API/org](https://github.com/aniskip/aniskip-api) and [extension HTTP client](https://github.com/aniskip/aniskip-extension/blob/main/src/api/aniskip-http-client/aniskip-http-client.ts) | Community interval lookup keyed by MAL anime ID + episode + runtime; opening, ending, mixed variants and recap | Simple backend HTTP adapter; voting and runtime selection | Needs accurate MAL/episode mapping; runtime compatibility does not establish identical cut; no episode filler label | First anime timing pilot |
| [Crunchyroll Companion](https://github.com/Donatoni/crunchyroll-companion) | Crunchyroll browser integration using per-episode static marker JSON and page fallback | Useful example of player controls and native-platform marker consumption | Crunchyroll/page-specific; no established general-purpose data reuse contract; no independent detector/filler dataset | UX/integration reference |
| [AniLiberty / AniLibria v1](https://api.anilibria.app/api/docs/v1/) | Release/episode metadata with duration and opening/ending start/stop; release MAL/Shikimori identifiers | Metadata and markers travel together; release identity can improve matching | Release-specific catalog; no filler field verified; documentation's beginning/end coordinate wording must be resolved before normalization | Optional matched-release source |
| [TheIntroDB org](https://github.com/TheIntroDB) / [npm SDK](https://github.com/TheIntroDB/theintrodb-npm) | TV/movie intro, recap, credits and preview arrays; TMDB/IMDb lookup, runtime selection | General media coverage intent; multiple intervals; anonymous public reads | Actual VIPTV coverage unmeasured; database/API reuse terms unverified; SDK GPL-3.0 is separate from data terms | First general-media timing pilot after terms check |
| [SkipDB](https://github.com/SkipDB-TV/skipdb) | Crowdsourced IMDb episode/movie markers, duration match metadata, dumps and mirrors | Self-hostable, public exports, votes/moderation | Additional data reciprocity affects private merge/cache/benchmark designs; runtime-shift heuristic is not detection; best single interval per kind | Optional open-data model, excluded from initial private-cache design |
| [Anime Skip public API](https://github.com/anime-skip/public-api) | Detailed anime segment types including Canon/Filler/Must Watch; GraphQL data | Richer segment semantics than just an OP/ED; potentially useful for mixed material | More involved show/episode/timestamp joins and access setup; segment Filler is not automatically whole-episode filler | Secondary anime pilot |
| [Open Anime Timestamps](https://github.com/jonbarrow/open-anime-timestamps) | Dejavu fingerprint experiments and aggregate anime opening-start dataset | Real detection reference and downloadable historical records | End times/durations unfinished; last reported push 2022; redistribution license not verified | Historical/algorithm reference |
| [AniProx API](https://github.com/beorgsh/AniProx-API) | Streaming-provider extraction passing through intro/outro objects | Demonstrates upstream marker shape | Dependent on third-party source pages and extractors; no independent editorial coverage or filler classifier; reuse license not verified | Avoid as default metadata dependency |
| [Cosmic API](https://github.com/JUSTCHILL098/cosmic-api) | Streaming scrape/extraction with upstream intro/outro fields | Existing passthrough values | Extractor/provider dependence; README educational/noncommercial; reusable license not verified | Avoid as default |
| [Anikoto API](https://github.com/zainaqdas/anikoto-api) | Scraped `skipData` payload | May expose available upstream hints | Payload is opaque rather than a verified stable typed marker contract; no filler classifier verified; reuse license not verified | Experimental only |
| [Miruro API](https://github.com/walterwhite-69/Miruro-API) | Proxy wrapper whose embedded docs show filler and intro/outro values | Closest of these scraper wrappers to both requested fields | Values originate upstream; no independent curation/classifier; reliability and data/code rights unresolved | Do not treat documented example fields as trusted coverage |
| [anime-vsub org](https://github.com/anime-vsub) | Player/extensions and `anime-skip-9animetv` upstream extraction proxy | Client integration examples | Organization is not a standalone skip/filler database; rapid-cloud marker dependency; separate project from Anime Skip public API | Reference only |
| [AnimeThemes docs](https://github.com/AnimeThemes/animethemes-api-docs) and [content reference](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/jsonapi/reference/content/index.md) | Theme identities, versions, clips and episode applicability strings | Useful for music/theme display and possible research inputs | Theme applicability is not the location in a full episode; no filler or selected-file marker contract; requested JSON:API docs are deprecated | Exclude from skip lookup MVP |
| [Intro Skipper](https://github.com/intro-skipper/intro-skipper) | Actual Jellyfin media analysis: chapter/audio/visual signals and durable corrections | Analyzes the actual accessible cut; can fill missing public markers | Jellyfin coupling, FFmpeg/Chromaprint and media access; scheduling/compute cost; no filler classification | Optional asynchronous detector later |
| [Fribb anime-lists](https://github.com/Fribb/anime-lists) | Cross-catalog anime IDs, seasons and episode offsets | Helps join TMDB/IMDb catalog entries to MAL providers | Does not provide timings or filler; mappings are not complete episode correspondence; merged-data license not verified | Identity helper after terms clarification |
| [Jikan](https://docs.api.jikan.moe/) — additional candidate | MAL-derived paginated episode `filler` and `recap` flags | Practical existing filler metadata with MAL alignment | Unofficial MAL parser, incomplete labels, rate/cache constraints; absence of a badge becomes `false`, which cannot establish canon | First positive-label filler pilot |
| [AnimeFillerList](https://www.animefillerlist.com/) — additional editorial candidate | Community whole-episode categories, including mixed canon/filler and anime canon | Richer editorial taxonomy than Boolean flags | No supported public integration API or reuse permission verified in this research; community judgments need provenance | Partnership/editorial reference, not an assumed scrape dependency |

The table is a synthesis. The supporting notes link exact schemas, implementation files, licenses, maintenance observations and unresolved questions for each row.

## Why these first

**AniSkip** exposes the information the anime player needs without a media-extraction dependency. Its source uses a ±20-second runtime filter and a 120 GET/minute throttle default; those source defaults are not a hosted SLA. **Anime Skip** is worth testing alongside it when precise segment classification matters. They should remain alternative candidates, not an indiscriminate merged interval list. Sources: [AniSkip source](https://github.com/aniskip/aniskip-api), [Anime Skip API](https://github.com/anime-skip/public-api).

**TheIntroDB** has a better documented first-adapter fit for general media than theme datasets or scrape wrappers: ID-based lookup, duration input, and arrays of supported segment types. Implementing the documented HTTP contract in Rust avoids importing a TypeScript runtime or copying the npm implementation. It does not resolve the separately unverified hosted-data terms. Sources: [SDK API functions](https://theintrodb.github.io/theintrodb-npm/functions.html), [types](https://theintrodb.github.io/theintrodb-npm/types.html).

**Jikan** supplies an episode-level path for filler that the marker APIs generally lack. Initially expose positive filler/recap observations and a neutral unmarked/unknown state. Preserve mixed classifications only when a source actually establishes them. Jikan's OpenAPI reports 3 requests/second, 60/minute and 24-hour caching; centralized request budgets and paginated episode caching matter. Sources: [Jikan OpenAPI](https://github.com/jikan-me/jikan-rest/blob/master/storage/api-docs/api-docs.json), [badge parser](https://github.com/jikan-me/jikan/blob/master/src/Parser/Anime/EpisodeListItemParser.php#L137).

For richer whole-episode editorial labels, **AnimeFillerList** deserves a data-access conversation. Its Naruto Shippuden guide distinguishes manga canon, mixed canon/filler, filler and anime canon; this is more expressive than MAL's badges. The page is community-maintained and identifies its update date and contributors. This confirms a useful taxonomy, not an automated integration right or universal accuracy. A partnered feed or explicitly licensed editorial overrides would be preferable to relying on an undocumented scrape. Sources: [community site](https://www.animefillerlist.com/), [example episode guide](https://www.animefillerlist.com/shows/naruto-shippuden).

**SkipDB** is attractive if VIPTV intentionally participates in an open marker database. Its declared ODbL-plus-reciprocity terms cover private record import, merging, validation and benchmarking, with a stated exception for pure read-only display without a private database of the same records. The recommendation here excludes it from private cached/merged marker storage and private-data benchmarking unless a compatible sharing model or written permission is established. This is a description of the published condition, not an enforceability opinion. Source: [SkipDB data license](https://github.com/SkipDB-TV/skipdb/blob/main/DATA-LICENSE).

## Three different capabilities

1. **Timestamp lookup:** an external service already knows that an opening occupies a particular interval. Lookup is relatively cheap, but identifiers and edition matching determine whether those timestamps apply.
2. **Detection:** a worker examines accessible media and produces intervals. This costs media access, CPU and storage, and usually needs multiple related episodes or a suitable signal. It cannot be assumed to work on an arbitrary remote IPTV URL without additional ingestion.
3. **Episode classification:** filler, mixed canon/filler, recap, and unknown describe editorial content. Audio similarity or the presence of an opening does not determine whether the story is filler.

These should have separate contracts, caches and success metrics. A recap interval is not an episode-level filler label; an ending-song video is not a timestamp in the selected episode file.

## VIPTV integration boundaries

The current design assigns accounts, profiles, catalogs, source discovery and history to the backend; the independent gateway takes generic media inputs and owns jobs and viewer leases. It explicitly avoids ambiguous episode remapping. Core owns shared normalization and behavior, while codecs and rendering belong to platform adapters. Roku remains independent of production core adoption. These are existing constraints, not new recommendations. Sources: [BE-002](https://github.com/viptv-org/design/blob/76ab36da2ad16896deb027d7af1f1c2250da3b6a/BACKEND_V2.md), [repository ownership](https://github.com/viptv-org/design/blob/76ab36da2ad16896deb027d7af1f1c2250da3b6a/REPOSITORIES.md), [core README](https://github.com/viptv-org/core/blob/91c5a4f53845ce0579f47caf1d57a74446710247/README.md), [video README](https://github.com/viptv-org/video/blob/main/README.md), [gateway README](https://github.com/viptv-org/playback-gateway/blob/764e518b66e024ac18d6dd7f14e489b696b8301e/README.md).

Inspected local revisions: design `76ab36da2ad16896deb027d7af1f1c2250da3b6a`; backend `ef7f2a7ff002f338d881eb82cf1c57b414c6ae05`; core `91c5a4f53845ce0579f47caf1d57a74446710247`; gateway `764e518b66e024ac18d6dd7f14e489b696b8301e`. Consumers have different immutable `DESIGN_REF` pins; this note does not change them.

| Layer / owning repo | Proposed responsibility | Why |
| --- | --- | --- |
| `design` | Specify marker types, button copy, timing, TV focus, user override, profile preferences, filler badges and queue semantics before implementation | Prevent clients from inventing different behavior |
| `backend` | Resolve exact episode identities; fetch and normalize external metadata; protect keys; cache, validate and rank marker candidates; persist provenance and profile preferences | One integration serves every client and keeps credentials and upstream quotas centralized |
| `core` | Normalize the new wire contract; derive active skip affordance and permitted seek intent; apply profile preferences and playback/session fences | Shared behavior for Android, browser and desktop |
| `tv-web`, `android`, `roku` | Render controls/badges and execute player actions; Roku implements the equivalent contract independently | Input, focus and native seek behavior vary by platform; adding Rust logic alone does not update Roku |
| `video`, `tauri-video-plugin`, Android Media3, Roku player | Report time/duration/seek capability and perform seeks on the existing playback path | A playback adapter should not discover titles or call AniSkip itself |
| Optional analysis worker | Inspect permitted media and return edition-bound detected intervals to the backend | Heavy work and new upstream media reads must not block playback startup |
| `playback-gateway` | Continue owning generic media delivery and source/output timeline facts; expose generic analysis capability only if explicitly designed later | MAL/TMDB identity, filler editorial policy and profile preferences do not belong in this independent service |

For a first implementation, prefer a separate bounded annotation read scoped to the authorized item/playback, so external-service latency does not hold up lease startup. This is a proposed API shape, not an existing endpoint. Protocol changes need explicit negotiation/adoption where existing DTOs are closed; regenerate core bindings and sync immutable consumer revisions. Sources: [playback protocol documentation](https://github.com/viptv-org/core/blob/91c5a4f53845ce0579f47caf1d57a74446710247/docs/playback-protocol.md), [BE-002](https://github.com/viptv-org/design/blob/76ab36da2ad16896deb027d7af1f1c2250da3b6a/BACKEND_V2.md).

The existing backend [continuation resolver](https://github.com/viptv-org/backend/blob/ef7f2a7ff002f338d881eb82cf1c57b414c6ae05/server/src/continuation.rs) finds a unique real episode from metadata, refuses ambiguous identity, checks release dates, and distinguishes specials ordering. Filler filtering should annotate or deliberately extend that resolver, preserving actual episode IDs and availability. Never compute the next episode by blindly incrementing a MAL or provider number. The existing core [seek policy](https://github.com/viptv-org/core/blob/91c5a4f53845ce0579f47caf1d57a74446710247/crates/viptv-core/src/policy/playback_control.rs) bounds seeks by duration or seekable range; segment skip should reuse the same limits.

## Native feature versus plugin

Here, a **backend adapter** is a replaceable implementation behind a VIPTV-owned metadata interface; a **plugin** is separately installed third-party execution; an **Addon** has the existing design meaning of account-configured catalog/source discovery. These are materially different deployment choices. Source for existing terminology: [design context](https://github.com/viptv-org/design/blob/76ab36da2ad16896deb027d7af1f1c2250da3b6a/CONTEXT.md).

| Option | Upsides | Downsides | Recommendation |
| --- | --- | --- | --- |
| Native feature + backend adapters | Works across Roku, Android, web and desktop; consistent preferences; central caching and ID matching; providers can be disabled/replaced without changing UI | VIPTV maintains schemas, migrations, adapters and acceptance checks; initial client releases required | Best fit |
| Backend remote metadata plugin protocol | Third parties can add coverage without changing the Rust implementation; deployments can opt in | Must design versioning, provenance, quotas, timeouts, isolation, endpoint trust and user configuration; another distributed failure boundary | Defer until a second independently maintained integration needs it |
| Existing Stremio-style Addon | Familiar installation and discovery model; metadata can be attached by an addon | Standard resources do not define a dedicated episode-segment/filler contract; private fields require VIPTV-specific support and consistent normalization | Possible future transport, not sufficient by itself |
| Browser extension | Fast browser-only proof of interaction | Does not serve native Android/Roku/Tizen consistently; depends on page/player internals; duplicates keys, requests and preferences | Reference implementation only |
| Jellyfin Intro Skipper plugin | Existing detection machinery if operating a Jellyfin library | A Jellyfin plugin cannot be installed directly into VIPTV's Rust service; adapting it adds a separate library/analysis system | Optional detection integration, not the main feature |

The published Stremio protocol lists `catalog`, `meta`, `stream` and `subtitles`; its `skip` catalog argument means pagination, not intro skipping. Standard discovery compatibility does not provide marker playback behavior. Sources: [protocol](https://stremio.github.io/stremio-addon-sdk/protocol.html), [manifest format](https://stremio.github.io/stremio-addon-sdk/api/responses/manifest.html).

## Proposed normalized data and safety rules

Preserve provider observations as candidates; expose only validated selected intervals to normal playback controls. Suggested fields, not a finalized wire schema:

- Episode identity: VIPTV series/episode IDs and verified external IDs, ordering scheme, season/cour/absolute mapping, mapping source and revision.
- Segment: type (`opening`, `ending`, `recap`, `preview`, optionally `mixed`/other), integer `start_ms` / `end_ms`, provider/record ID, provider-native segment type, evidence and retrieval time.
- Applicability: reference duration, selected-source revision, edition/language information when available, and whether the match was exact, runtime-compatible, manually corrected, or uncertain.
- Classification: `canon`, `filler`, `mixed`, `recap`, `unknown`, or a narrower initial `filler`/`unknown` contract if the chosen data does not support the richer distinctions. Preserve upstream observations; do not manufacture mixed/canon categories from a Boolean.
- Classification evidence: source, external episode ID, observation date and editorial/manual override. A missing record is `unknown`; an upstream `false` remains a sourced claim whose confidence depends on coverage.

Recommended rules:

1. Convert documented units explicitly; reject non-finite, negative, reversed, zero-length or out-of-duration intervals. Preserve supported multiple intervals rather than hard-coding one opening at zero.
2. Cache by external episode identity plus applicable edition/runtime and adapter schema revision. Source-specific corrections are private to their authorized scope; public source metadata can be shared only where terms permit. Use bounded positive caching, shorter negative caching, request coalescing and backoff.
3. Keep marker-provider errors separate from valid no-data responses. Both allow normal playback to continue. Never send media URLs, headers or account credentials to a public timestamp service.
4. Use observed runtime as a compatibility check, not proof of the same cut. Do not proportionally rescale all markers or invent a global offset merely to force a match. Manual offsets need a clearly bound source/edition and revision.
5. Rank candidates by episode/edition evidence, known duration and provider validation. Do not union conflicting provider intervals: that can remove actual story content. Retain contradictions for correction and evaluation.
6. Store intervals on the source's absolute timeline. Translate through actual gateway/native delivery offsets; a managed output starting at minute ten may have a player clock starting at zero. Refresh/fence results on source switch, episode switch, lease replacement and cancellation. Direct/native playback must work without a gateway.
7. Default to an explicit Skip opening/ending action. Automatic skipping is opt-in and restricted to validated intervals, with per-session suppression after a user seeks back. Preserve mixed opening/credits types and exclude them from automatic skipping by default because they may contain story material. An outro skip seeks to its end; changing episode is a separate action, so post-credit scenes are not silently discarded.
8. Show filler badges before introducing optional queue filtering. Mixed/unknown episodes remain playable; skipping filler does not mark it watched or erase history. Preserve the ordinary Next episode path unless a profile explicitly chooses an alternate filter.
9. Disable this episode feature for live IPTV, uncertain identity, unseekable streams, and incompatible source revisions. Do not run a season scan during source discovery.

These are engineering recommendations derived from VIPTV's ownership and timeline constraints; they are not capabilities promised by the upstream APIs.

## Validation before selecting production defaults

After establishing compatible data terms, run a reproducible pilot across VIPTV's actual catalog: long-running anime with filler, separate MAL cours, specials/OVAs, dubbed/subbed cuts, general TV, and editions with recap/ad differences. Compare the same episode set across permitted candidate services. Exclude SkipDB from private-data benchmarking until its reciprocity conditions have a compatible workflow. Record sample size, lookup hit rate, exact ID resolution rate, start/end error against human-checked ground truth, incorrect skip rate, latency and quota consumption. Do not equate GitHub stars, dataset size or a successful HTTP request with useful catalog coverage.

Exercise direct and managed seek timelines, source changes during requests, seek-back suppression, repeated remote presses, unknown runtime, provider failure, late response after profile change, outro with post-credit scene, missing filler classification and unavailable next episode. Device evidence is needed for Roku, Android TV, Tizen and Vizio; host unit tests cannot prove those seeks or focus behavior.

Suggested rollout: research → representative lookup pilot → design-owned specification → backend annotations and filler badges → explicit skip actions on each client → opt-in automatic skip/filler filtering → optional local analysis. Deployment remains a separate activity.

## Limitations

No production credentials, media provider connections, device sessions, deployments or bulk upstream scans were used for this research. No comparative accuracy benchmark was performed. An open-source server/client license does not automatically license its hosted data or permit unlimited caching/redistribution. Confirm operational quotas, attribution, retention and data terms before enabling a service by default. Detailed source notes separate documented facts from unresolved issues.
