# General skip sources and anime identity mapping

Researched 2026-10-07 against first-party documentation, repositories and GitHub metadata. This is a provider comparison and architectural recommendation, not an implementation or an accuracy benchmark. Catalog coverage, precision on VIPTV streams and production availability have not been measured.

## Recommendation

For general TV and movies, evaluate **TheIntroDB as the first hosted lookup adapter**, subject to confirming its API/data caching and commercial-use terms. Evaluate **SkipDB as an optional open-data adapter** only after deciding whether VIPTV can meet its additional reciprocity terms. Use **intro-skipper as a reference or optional server-side analysis integration** when VIPTV actually has authorized access to complete, seekable media files. Use **Fribb/anime-lists for identity enrichment**, never as evidence that an episode is filler.

The native product feature should consume a provider-neutral segment contract. Keep provider lookup and normalization in the backend, user preferences and skip decisions in shared client state, and seeking in the playback adapter. An optional provider or detector module is useful; making the entire experience an installable player plugin would duplicate behavior across web, Android, Roku and desktop. These are architectural judgments, not statements about an existing VIPTV implementation.

## TheIntroDB and theintrodb-npm

The organization describes a community-supplied database covering TV and movies and lists integrations for Jellyfin, Emby, Kodi, Stremio, Plex, MPV, IINA and browsers. The integrations demonstrate intended cross-player consumption, not a measured catalog coverage guarantee. [Organization](https://github.com/TheIntroDB)

The SDK documents public `GET /media` reads; an optional individual API key may include that user's pending contributions. Writes require the current user's API key and explicitly should not use a shared application key. The TypeScript package validates requests and responses and normalizes timestamps. [SDK README](https://github.com/TheIntroDB/theintrodb-npm/blob/main/README.md)

Lookup accepts TMDB ID, or IMDb fallback, plus season/episode for TV. `durationMs` selects the closest release runtime; submissions can include `videoDurationMs`. This is useful for theatrical/extended or other release differences, but duration similarity alone cannot prove identical editing. No accessible algorithm specification establishes a guaranteed tolerance or correctness. [Function documentation](https://theintrodb.github.io/theintrodb-npm/functions.html)

The documented segment kinds are `intro`, `recap`, `credits` and `preview`; each is an array, so multiple segments of one kind are possible. Null starts mean media beginning; null ends mean media end. The normalized record has no filler classification or release confidence field in its published schema. Missing arrays become empty arrays, which should represent unavailable data rather than proof of absence. [Types](https://theintrodb.github.io/theintrodb-npm/types.html)

The inspected SDK defaults to `https://api.theintrodb.org/v3`; lookup serializes the optional duration as `duration_ms`. This is a thin HTTP client rather than an offline detector. Its transport exposes abort signals and errors, but no persistent response cache is advertised. [Client implementation](https://github.com/TheIntroDB/theintrodb-npm/blob/main/src/funcs.ts)

Rate/usage error metadata is parsed from `X-RateLimit-*` and `X-UsageLimit-*` headers, but the SDK error docs do not promise numeric production quotas. [Errors](https://github.com/TheIntroDB/theintrodb-npm/blob/main/docs/errors.md)

The package is GPL-3.0; that is the client code license, not proof that the database has the same license. The first-party sponsorship page describes a free, volunteer-built service funded by donations. Public repository inspection did not establish downloadable backend source or a documented full database export. The web docs rendered only a shell through the research tools, so API terms, caching permission, bulk export rights, commercial reuse rights and any SLA remain **unverified**, not assumed prohibited or permitted. [SDK license](https://github.com/TheIntroDB/theintrodb-npm/blob/main/LICENSE), [First-party funding statement](https://github.com/sponsors/TheIntroDB), [Docs entrypoint](https://theintrodb.org/docs)

**Upsides:** broad intended media scope, runtime-aware lookup, multiple same-type intervals, anonymous read access and existing player integrations.

**Downsides:** unknown measured coverage and edition accuracy; external service dependency; unresolved database/API terms; GPL client compatibility should be considered before embedding the npm package. A Rust backend can implement the documented HTTP contract independently, while still needing to respect API/data terms.

## SkipDB

SkipDB supplies crowdsourced intro, recap, outro and preview intervals for TV and movies, keyed by IMDb plus season/episode. Reads are open; writes use a session or API key. It documents daily GitHub release exports containing statuses and votes without user PII, and read-only mirror/full-fork setup. The Next.js application uses PostgreSQL/Drizzle, and a mirror can import the public dump. Its public read response chooses one best interval per type, unlike TheIntroDB's arrays. The README's dump size is a project statement, not a fresh measured count. [README](https://github.com/SkipDB-TV/skipdb/blob/main/README.md)

Current inspected configuration uses a 2-second exact-duration tolerance and a 15-second shift tolerance. The default conservative adjustment shifts earlier for shorter media but does not shift later for longer media; greedy mode shifts either way and none mode keeps original bounds. The underlying heuristic assumes the runtime difference comes from a leading logo/scene. That assumption fails when differences occur mid-episode or at the end, or from speed changes. This is matching heuristics, not content detection. [Configuration](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/config.ts), [Duration logic](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/duration.ts)

The resolver can return an `out-of-range` candidate when no closer candidate exists. Responses carry `match` and `confidence`; a `0,0` absence sentinel becomes null. Consumers must inspect match metadata before offering automatic skips. The no-adjust mode can label within-tolerance differences exact while retaining their offset, so consumers should retain offset metadata too. [Segment resolver](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/segments.ts), [Duration logic](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/duration.ts)

The read route advertises shared-cache freshness of 30 seconds with stale-while-revalidate of 300 seconds; the inspected default configuration limits reads to 120/minute per IP. These are source defaults, not proof of current hosted edge quotas. The local limiter is in-memory and its source notes that multiple instances need a shared replacement. A VIPTV backend proxy would aggregate many viewers behind one source IP and therefore needs upstream budget controls. [Read route](https://github.com/SkipDB-TV/skipdb/blob/main/src/app/api/segments/route.ts), [Rate limiter](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/rate-limit.ts), [Configuration](https://github.com/SkipDB-TV/skipdb/blob/main/src/lib/config.ts)

**Material licensing difference:** application code is AGPL-3.0, while data/API content is ODbL 1.0 **plus additional service-provider reciprocity**. The additional terms say that importing, merging, correcting, validating or benchmarking private skip records using SkipDB data triggers public machine-readable bulk availability of the skip records for the same titles, episodes and segment kinds. The text explicitly says: "satisfying ODbL 1.0 Share-Alike alone (Section 4.4) is necessary but not sufficient." Independently collected records never referenced to SkipDB have a safe harbor. Read-only end-user display without maintaining a private database of the same records is excluded. Hosting alone does not avoid this condition. Therefore a unified private metadata cache/merge cannot simply be assumed acceptable; choose an open export model, obtain written permission, or omit this adapter. This is a reading of the project's declared terms, not a legal enforceability opinion. [Data license](https://github.com/SkipDB-TV/skipdb/blob/main/DATA-LICENSE), [Code license](https://github.com/SkipDB-TV/skipdb/blob/main/LICENSE)

**Upsides:** practical self-hosting and mirrors, exports reduce dependence on one instance, useful duration/match metadata, moderation and votes.

**Downsides:** reciprocity affects the desired unified backend database; duration shifting is unsafe as an automatic content-equivalence test; one best interval per kind loses multi-part recaps; real VIPTV coverage remains unmeasured. No filler field exists in the inspected four-kind contract.

## intro-skipper/intro-skipper

This is a Jellyfin plugin that analyzes media, rather than a hosted shared timestamps API. Current 12.0 documentation requires Jellyfin 12 and Jellyfin FFmpeg 7.1.3-1 or newer, with Chromaprint support. Its source is GPL-3.0. A prebuilt plugin cannot be loaded into VIPTV's Rust backend without an integration boundary or port; GPL reuse and FFmpeg/Chromaprint packaging need their own assessment. [README](https://github.com/intro-skipper/intro-skipper/blob/12.0/README.md), [License](https://github.com/intro-skipper/intro-skipper/blob/12.0/LICENSE)

Detection combines named chapter markers, repeated-audio matching via Chromaprint, black-frame/credit visual analysis and silence-based boundary refinement. Silence is not a standalone detector. It handles intros, credits, recaps, previews and commercials; movies have separate analysis behavior. Shared-audio matching benefits from multiple matching episodes. Analysis and fingerprints are cached against media-file versions and configuration. User edits and suppression of automatic detections are durable; the plugin database projects to Jellyfin's MediaSegments API. This design is a useful reference for keeping detection evidence and manual corrections distinct. None of these methods classifies an episode as filler. [Detection and data model](https://github.com/intro-skipper/intro-skipper/wiki)

Documented performance settings include bounded concurrent analysis, FFmpeg priority/thread controls, a default 300-second scan timeout and compressed fingerprint caches. This demonstrates schedulable compute, but provides no transferable throughput guarantee for VIPTV hardware or streams. [Performance settings](https://github.com/intro-skipper/intro-skipper/wiki/Settings-%E2%80%90-Performance)

**Upsides:** analyzes the actual edition, can work without external timestamp coverage, chapters are cheap when available, reusable evidence and durable human overrides.

**Downsides:** needs accessible media bytes, seeking and often a season cohort; FFmpeg I/O/CPU expense; local-media/Jellyfin coupling; repeated theme music and credits containing story material can create false positives. Remote live channels and opaque provider streams are poor first targets. Schedule analysis before playback where possible, and avoid blocking playback on detection.

## Fribb/anime-lists

This is an anime identity mapping dataset, not an intro/outro or filler database. It maps AniDB, AniList, MAL, Kitsu, IMDb, TMDB, TVDB and other sources; contains TMDB/TVDB season and episode offsets; and provides static JSON indices and collections. The README says records are generated from upstream anime lists and supplemented with TMDB lookups, with corrections made upstream. Media kind matters: numeric TMDB/TVDB IDs can refer to different movies and TV records. These mappings can bridge a TMDB catalog to a MAL-keyed anime segment provider, but offsets are not a complete per-episode edition/numbering resolver. [Dataset contract](https://github.com/Fribb/anime-lists/blob/master/README.md)

The inspected tree has no top-level license file and GitHub reports `license: null`. This does not establish that the upstream material is unlicensed, but a redistribution license for this merged product was not verified. Check applicable upstream licenses and owner clarification before shipping a local mirror. The JSON files can technically be downloaded and indexed without an authenticated API; pin snapshots and provenance instead of making runtime GitHub requests for every viewer. [Repository metadata](https://api.github.com/repos/Fribb/anime-lists), [Inspected tree](https://api.github.com/repos/Fribb/anime-lists/git/trees/master?recursive=1)

**Upsides:** improves deterministic joins across otherwise incompatible source IDs; static indices support fast local lookup.

**Downsides:** generated mapping errors and incomplete episode correspondence; upstream correction delay; unresolved merged-data license; supplies neither skip timings nor filler classifications.

## Maintenance observations and remaining validation

All four repositories reported unarchived when checked. Default-branch heads inspected: TheIntroDB SDK `c2862cc71625faa3e17488f8fb457c8a5b351fe7` (2026-09-15); SkipDB `4911eb4895f6ac96507bf334c7ff3334b91ecd2f` (2026-09-03); intro-skipper `ce8feaee27d1e33d1ae3f48c6ea4a3181e9ca9ef` (2026-10-05); Fribb `4c3e5ff72b7cde4ce1eba4e366a64d16ac282e14` (2026-10-06, automated list update). Repository `pushed_at` can reflect releases or other branch activity and is not equivalent to a code update. Recent commits do not prove uptime, support capacity or timestamp accuracy. [SDK history](https://api.github.com/repos/TheIntroDB/theintrodb-npm/commits?per_page=1), [SkipDB history](https://api.github.com/repos/SkipDB-TV/skipdb/commits?per_page=1), [Detector history](https://api.github.com/repos/intro-skipper/intro-skipper/commits?per_page=1), [Mapping history](https://api.github.com/repos/Fribb/anime-lists/commits?per_page=1)

Before selecting a default, establish data/API permissions, then test a representative owned/authorized sample: anime plus general TV, absolute versus seasonal numbering, dub/sub, different release edits, missing intros and post-credit scenes. Measure correct ID joins, coverage and safe interval boundaries independently. Never infer filler from repeated openings, missing timestamps or an ID mapping. Keep filler as editorial episode metadata with source and classification uncertainty.
