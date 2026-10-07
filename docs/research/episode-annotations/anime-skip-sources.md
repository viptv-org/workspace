# Anime timing sources: AniSkip, Anime Skip, AniLiberty and reference implementations

Researched 2026-10-07 against first-party documentation, repository source and read-only API requests. Recommendations below are judgments; neither public reachability nor a software license establishes permission to redistribute a hosted service's database. No credentials were created and no provider writes were performed.

## Findings at a glance

| Source | What it actually offers | Filler evidence | Suggested role |
| --- | --- | --- | --- |
| AniSkip API / organization / extension client | Community-submitted, voted anime OP/ED/recap intervals keyed by MAL ID, episode and approximate duration | No filler type in v2 | First anime timing adapter to pilot |
| Anime Skip public API | Community-maintained typed timeline boundaries, episode URLs, duration offsets and AniList links | Explicit **segment-level** Filler type; not established as a comprehensive episode filler list | Rich optional secondary adapter after registering a client |
| AniLiberty / AniLibria v1 | OP/ED intervals accompanying its own releases, with nullable MAL cross-reference | No filler field found in episode schema | Optional fallback when release identity and edit match |
| Crunchyroll Companion | Browser extension consuming Crunchyroll's per-episode static JSON and native skip buttons | No episode filler classification | UX/parser reference; conditional provider-specific adapter, not independent database |
| Open Anime Timestamps | Historical JSON dataset plus acoustic fingerprinting and aggregation tool | No filler output | Research reference, not initial production dependency |

Detailed source citations and limitations follow.

## AniSkip

The supplied HTTP client reads `https://api.aniskip.com/v2/skip-times/{malId}/{episodeNumber}`, passing requested types and duration rounded to three decimal places. It also reads `relation-rules/{malId}` for episode redirection. The five types are `op`, `ed`, `mixed-op`, `mixed-ed` and `recap`; responses carry explicit start/end intervals, type, skip UUID and contributed episode duration. This is a lookup client, not a video detector. [Supplied client](https://github.com/aniskip/aniskip-extension/blob/main/src/api/aniskip-http-client/aniskip-http-client.ts), [types](https://github.com/aniskip/aniskip-extension/blob/main/src/api/aniskip-http-client/aniskip-http-client.types.ts).

The API stores user submissions and votes. Selection excludes entries with votes at or below -2, filters contributed duration to within **20 seconds** of requested duration, orders by votes and selects one result per requested type. `episodeLength=0` disables duration filtering; it does not establish a correct playback edit. The repository's source does not return votes or a confidence score in this read response. Equal runtime is therefore useful matching evidence, not proof of equal timing. [Repository query](https://github.com/aniskip/aniskip-api/blob/main/src/repositories/skip-times.repository.ts), [v2 service](https://github.com/aniskip/aniskip-api/blob/main/src/skip-times/skip-times.service.v2.ts).

Source-declared throttles are 120 GETs/minute, 10 submissions/day and 4 votes/hour; read routes have no API-key guard in this controller. Missing timing returns HTTP 404 with `found=false`, so adapters should distinguish a normal miss from outage. Hosted infrastructure may impose further limits; the source declaration is not an SLA. [Controller](https://github.com/aniskip/aniskip-api/blob/main/src/skip-times/skip-times.controller.v2.ts).

Episode relation rules parse MAL ranges from an anime-relations file; VIPTV must preserve the distinction between local season numbering, absolute numbering and MAL season-specific entries. These rules supplement identity mapping; they do not justify fuzzy title-only matching. [Relation-rule service](https://github.com/aniskip/aniskip-api/blob/main/src/relation-rules/relation-rules.service.ts).

The API and extension software are MIT licensed. GitHub repository metadata reported last push 2024-01-04 for API and 2026-07-11 for extension, neither archived. Push dates alone do not demonstrate hosted-service maintenance. [API license](https://github.com/aniskip/aniskip-api/blob/main/LICENSE), [extension license](https://github.com/aniskip/aniskip-extension/blob/main/LICENSE), [API metadata](https://api.github.com/repos/aniskip/aniskip-api), [extension metadata](https://api.github.com/repos/aniskip/aniskip-extension).

**Upsides:** narrow API, no read credential observed, explicit intervals, runtime filtering, meaningful distinction for plot-overlaid openings/endings. **Downsides:** crowdsourced misses/errors, MAL and episode identity work, ±20-second filter can admit a wrong edit, public dataset redistribution/cache terms and service SLA not established. Recommended backend adapter with shared positive/negative caching and administrator corrections; never invoke per playback tick.

## Anime Skip public API

Anime Skip and AniSkip are separate projects. Anime Skip's GraphQL queries support lookup by episode URL, internal show/episode UUID, show external ID, title and episode list. The schema identifies URL lookup as the preferred method; name lookup is a fallback that can return multiple candidates. Current `ExternalService` enum contains AniList. A title search result must not silently become a reliable match. [Queries](https://github.com/anime-skip/public-api/blob/main/api/queries.graphqls), [enums](https://github.com/anime-skip/public-api/blob/main/api/enums.graphqls).

Timestamp records contain `at: Float` and a type, rather than independent start/end intervals. Convert ordered boundaries into segments using the next boundary, or a validated final duration. Episode models preserve string season/number, absolute number, base duration and per-URL `timestampsOffset`. The documented suggested offset is URL duration minus base duration, based on branding differences at the beginning; edits within an episode break that assumption. Preserve explicit offset evidence instead of blindly applying runtime arithmetic. The type catalog is suitable for caching. [Models](https://github.com/anime-skip/public-api/blob/main/api/models.graphqls), [boundary validation](https://github.com/anime-skip/public-api/blob/main/internal/validation/episode_timestamps.go).

Seeded types include Canon, Must Watch, Branding, Intro, Mixed Intro, New Intro, Recap, Filler, Transition, Credits, Mixed Credits, New Credits, Preview and Title Card. Filler describes content without bearing on the story, and Must Watch covers worthwhile noncanon content. This supports **filler segments**, not evidence that every episode is classified as canon/mixed/filler. Do not convert one filler segment into a whole-episode filler badge or skip. [Type seed](https://github.com/anime-skip/public-api/blob/main/internal/postgres/migrations/seeders/01_timestamp_types.go).

Every GraphQL request requires a registered `X-Client-ID`; a user Bearer token is additionally required for authenticated operations. Client creation is an authenticated mutation. The HTTP rate limiter applies the client record's configurable requests/minute and returns a GraphQL error when exceeded; a nullable limit is represented in source, so no universal numeric public quota was established. [Client middleware](https://github.com/anime-skip/public-api/blob/main/internal/http/chi_server.go), [mutations](https://github.com/anime-skip/public-api/blob/main/api/mutations.graphqls), [rate limiter](https://github.com/anime-skip/public-api/blob/main/internal/http/rate_limiter.go).

Public API software is GPL-3.0. Consuming its service is different from embedding/forking GPL code; hosted data terms still need separate confirmation. GitHub metadata reported last push 2026-08-19, not archived. [License](https://github.com/anime-skip/public-api/blob/main/LICENSE), [metadata](https://api.github.com/repos/anime-skip/public-api).

**Upsides:** richer semantics, identity-linked URLs, explicit timeline offset model, contribution workflow. **Downsides:** client registration and quota dependency, conversion complexity, sparse/unmeasured coverage, GPL implications if code is embedded, whole-episode filler coverage unproven. Recommended secondary backend adapter and useful domain-model reference.

## AniLiberty / AniLibria v1

The supplied Swagger page is current AniLiberty v1 documentation. Its underlying document is `/storage/api/docs/v1?aniliberty-api-v1-docs.json`, fetched successfully with an ordinary browser User-Agent after an initial 403. Old AniLibria v2/v3 GitHub docs explicitly declare themselves deprecated; their `skips.opening` array examples must not be mistaken for v1 schema. [Current Swagger](https://api.anilibria.app/api/docs/v1/), [Swagger JSON](https://api.anilibria.app/storage/api/docs/v1?aniliberty-api-v1-docs.json), [official legacy docs](https://github.com/anilibria/docs).

V1 episode schema has a UUID, numeric/fractional `ordinal`, release ID, duration in seconds, and `opening` / `ending` objects with numeric `start` / `stop`. Skip descriptions say seconds from the **beginning or end**; that wording leaves origin semantics to resolve before implementing. Release schema supplies nullable `mal.id` and `shikimori.id`, so mapping is more practical than title search alone. Episode schema contains no filler property. The document declares Bearer session security globally, but a read-only anonymous request to `/api/v1/anime/releases/jujutsu-kaisen` returned HTTP 200. This verifies that request, not every route or future authentication policy. [Swagger JSON](https://api.anilibria.app/storage/api/docs/v1?aniliberty-api-v1-docs.json).

**Upsides:** own-release markers and duration, MAL link, simple intervals. **Downsides:** timings are specific to its supplied release/edit, nullable intervals, unresolved endpoint time-origin wording, no filler evidence, no numerical rate limit or data-reuse license verified. This is an optional timing source where source identity can be established; do not generalize its timings to every release.

## Crunchyroll Companion

The extension reads `static.crunchyroll.com/skip-events/production/{episodeId}.json`. Parser accepts finite increasing `start` / `end` pairs for intro, recap, credits and preview. The extension documents fallback to clicking Crunchyroll's native skip button. This is reuse of platform-published metadata, not acoustic or visual detection and not a general anime API. [Parser](https://github.com/Donatoni/crunchyroll-companion/blob/main/src/shared/skip-events.ts), [README skipping behavior](https://github.com/Donatoni/crunchyroll-companion#how-skipping-works).

The background worker fetches with credentials omitted, deduplicates concurrent requests and caches parsed segments in memory. This illustrates request coalescing; browser memory caching is not the desired persistent cross-device VIPTV store. Its native-button fallback requires the Crunchyroll DOM and cannot be transplanted into VIPTV's own player. [Worker](https://github.com/Donatoni/crunchyroll-companion/blob/main/src/background/service-worker.ts).

Software is MIT licensed; GitHub metadata reported last push 2026-09-04, not archived. No first-party Crunchyroll general-purpose API contract, redistribution license, rate policy or availability guarantee for this static endpoint was verified here. MIT licensing of the extension does not license Crunchyroll's data. [License](https://github.com/Donatoni/crunchyroll-companion/blob/main/LICENSE), [metadata](https://api.github.com/repos/Donatoni/crunchyroll-companion).

**Upsides:** exact provider episode identity, extra recap/preview markers, useful undo/per-type UX examples. **Downsides:** provider IDs and edition mapping needed, undocumented external contract, provider-dependent coverage, no filler classification. Treat as implementation reference or explicitly enabled provider-specific adapter after confirming permitted use.

## Open Anime Timestamps

This tool aggregates Anime Skip/BetterVRV markers and performs actual acoustic matching of theme music to episode audio with Dejavu. JSON keys are AniDB series IDs; records store episode number, source and opening/ending/recap/preview **starts** in seconds, using -1 for missing values. The README still lists adding opening/ending durations as unfinished. [README](https://github.com/jonbarrow/open-anime-timestamps/blob/master/README.md), [aggregation pipeline](https://github.com/jonbarrow/open-anime-timestamps/blob/master/main.py).

Fingerprint implementation takes the first recognition result, applies absolute value and floors the start time. It includes a TODO for no-match handling; reliable production confidence/rejection is not implemented there. README warns about songs repeated inside an episode, absent themes and high memory use. Detection cannot identify filler canon status. [Fingerprint implementation](https://github.com/jonbarrow/open-anime-timestamps/blob/master/fingerprint.py).

The fetched JSON snapshot contained 10,321 series keys, but only **709 nonempty series and 7,869 episode records**; empty keys are not coverage. GitHub metadata reported last push 2022-08-10, not archived, license null, and the repository tree contained no LICENSE file. No explicit data/software reuse license was found. [Dataset](https://github.com/jonbarrow/open-anime-timestamps/blob/master/timestamps.json), [repository metadata](https://api.github.com/repos/jonbarrow/open-anime-timestamps).

**Upsides:** useful demonstration of reference-theme fingerprinting, inspectable offline data. **Downsides:** old scraper ecosystem, no interval ends, unchecked matching failures, license uncertainty and no evidence of current maintenance. Use the idea for a separately assessed backend analysis worker, not this repository as a turnkey production dependency.

## Small live comparison

For MAL 40748, episode 1, requested runtime 1435 seconds, anonymous AniSkip returned OP **54.711–145.111** and ED **1338.255–1428.255**. AniLiberty's same named release exposed MAL 40748, 24 episodes and duration 1435 for its first episode, but OP **56–145** and null ED fields. These are successful read observations on the research date, not a coverage or accuracy benchmark. They demonstrate that identity/runtime alignment can coexist with differing markers and missing data. [AniSkip sample request](https://api.aniskip.com/v2/skip-times/40748/1?types%5B%5D=op&types%5B%5D=ed&episodeLength=1435), [AniLiberty release request](https://api.anilibria.app/api/v1/anime/releases/jujutsu-kaisen).

## Integration implications

Recommendation: native user-facing skip/filler behavior consuming a stable normalized metadata contract, with replaceable backend provider adapters. Keep provider IDs, quotas, caching, lookup failures and data provenance out of playback engines. Store episode editorial classification separately from media-version-specific intervals. Server-side acoustic analysis should be a background job when media access is available; playback clients should consume validated results and execute seeks.

Preserve mixed intro/credits semantics, show normal skip controls before enabling automatic behavior, and retain unknown classification as unknown. Neither absent markers nor a recap/filler segment establishes an entire filler episode. These are design recommendations drawn from the source distinctions above; platform-specific ownership is covered by the parent research report.
