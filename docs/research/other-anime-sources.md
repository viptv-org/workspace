# Secondary anime sources, theme references, and filler metadata

Research date: 2026-10-07. Scope: the user-supplied AniProx, Cosmic, Anikoto, Miruro, AnimeVsub, and AnimeThemes links; Jikan and Anime Filler List as filler alternatives. This is research, not an implementation decision or availability certification.

## Findings

None of the four streaming wrappers is an independent timestamp detector or a verified, reusable filler dataset. Several really expose skip metadata, but it belongs to their upstream stream edition. Prefer a metadata enrichment provider behind the VIPTV backend; do not embed another site's player as the platform's skip feature. These are architectural recommendations inferred from the source behavior below.

| Source | Verified relevant capability | Identity | Recommendation |
| --- | --- | --- | --- |
| AniProx | Passes through `intro` / `outro` | Site slug plus merged episode index | Exclude from initial metadata providers |
| Cosmic | Passes through nullable `intro` / `outro`; embed player uses them | AniList ID, episode, sub/dub and upstream server | Exclude: upstream extractor and commercial-use restriction |
| Anikoto | Passes through opaque `skipData`; no normalized ranges documented | Site anime/episode slugs; episode also exposes `malId` | Exclude until schema, identity and permission are established |
| Miruro | Examples contain `filler`, `intro` and `outro`; runtime proxies upstream payloads | AniList ID plus provider/category/episode slug | Optional experiment only; unsupported as primary filler source |
| AnimeVsub | Relevant `anime-skip-9animetv` scraper exposes intro/outro | Name search then site episode ID | Exclude from initial providers |
| AnimeThemes | OP/ED theme identity, versions, episode applicability and reference clips | Anime/theme resource IDs with external mappings | Optional research aid for later fingerprinting, not timestamp lookup |
| Jikan | Episode `filler` and `recap` flags scraped from MAL | MAL title ID and title-relative episode number | Best candidate here for an MVP filler badge, with unmarked/unknown semantics |

The table summarizes the per-source evidence linked below. “No field found” describes inspected code and documentation; it does not prove every possible upstream response lacks that field.

## AniProx-API

The README documents merged AnimePahe/HiAnime episodes and per-server start/end ranges. In `main.py`, the stream fetcher simply copies `streaming.get("intro")` and `streaming.get("outro")`; it does not analyze media. No filler or recap field was found in that file or the documented response. [README](https://github.com/beorgsh/AniProx-API), [source](https://github.com/beorgsh/AniProx-API/blob/65d9b4a22c25134482e7203c632a6772a07cea97/main.py#L213).

Upside: simple normalized ranges and partial upstream failure handling. Downsides: multiple upstream services, site-specific identity, episode merging by index, and no source-edition alignment guarantee for VIPTV media. The README itself lists upstream dependency and no caching as limitations. It describes personal/educational use; the inspected tree has no LICENSE file and GitHub returns `license: null`. Last default-branch commit: 2026-03-17. [Repository metadata](https://api.github.com/repos/beorgsh/AniProx-API), [commit history](https://github.com/beorgsh/AniProx-API/commits/main/).

Recommendation: do not make it the platform's timestamp authority. Its consumer-oriented response format is useful as an example, not evidence that timestamps match another copy of an episode.

## Cosmic API

The README describes a Next.js embed/player and stream API, with nullable ranges and sub/dub servers. It explicitly limits intended use to educational purposes and says it is not for commercial usage. [README](https://github.com/JUSTCHILL098/cosmic-api).

`lib/megaplay.ts` looks up a provider embed by AniList ID, episode number and language, extracts a player ID, fetches its sources and returns `src.intro || null` / `src.outro || null`. `lib/anikoto.ts` likewise copies upstream JSON ranges. These are upstream metadata, not generated boundaries. No filler/recap classifier was found in these extractors or the resolver. [MegaPlay extractor](https://github.com/JUSTCHILL098/cosmic-api/blob/c79c50f8b7f4ab08fa924cc0eb5514ad211c6717/lib/megaplay.ts), [Anikoto extractor](https://github.com/JUSTCHILL098/cosmic-api/blob/c79c50f8b7f4ab08fa924cc0eb5514ad211c6717/lib/anikoto.ts).

Upside: AniList lookup and language/server-specific ranges. Downsides: scraping, stream-provider dependencies, nullable coverage and an embedded player that would bypass VIPTV's shared playback behavior. No LICENSE file was found; GitHub reports `license: null`. Last default-branch commit: 2026-08-11. [Metadata](https://api.github.com/repos/JUSTCHILL098/cosmic-api), [history](https://github.com/JUSTCHILL098/cosmic-api/commits/main/).

Recommendation: exclude from a commercial platform shortlist without explicit permission and an independent reason to use its upstream data.

## Anikoto API

This is an Express/Cheerio scraper of `anikototv.to`, covering catalog, episodes and streaming server URLs. [README](https://github.com/zainaqdas/anikoto-api).

The actual scraper returns `skipData: sd.result.skip_data || null` in episode-source responses. It does not normalize the object into documented intro/outro start/end ranges. Episode parsing includes `malId`, number, slug and an unrelated `timestamp` attribute; the attribute is not documented as a skip boundary. No filler or recap field was found in the scraper. [Pinned scraper source](https://github.com/zainaqdas/anikoto-api/blob/2fdabe64fa8525115dd69b15a36a8e26748b879d/scraper/scraper.js#L357).

Upside: can preserve source skip metadata and an external identifier. Downsides: opaque schema, site-specific episode identity, HTML coupling and no independent data provenance. No LICENSE file was found; GitHub reports `license: null`. The repository had one default-branch commit, dated 2026-05-18. [Metadata](https://api.github.com/repos/zainaqdas/anikoto-api), [history](https://github.com/zainaqdas/anikoto-api/commits/main/).

Recommendation: not a stable timestamp/filler provider. Do not confuse this standalone repository with Cosmic's separate Anikoto extractor.

## Miruro API

The README describes a reverse-engineered Python proxy for Miruro's encrypted transport. It warns that its upstream secure endpoint is Cloudflare-protected and may reject hosting IPs. [README](https://github.com/walterwhite-69/Miruro-API).

`api.py` embeds example episode JSON with `filler: false` and stream JSON with intro/outro ranges. Runtime `/episodes/{anilist_id}` retrieves upstream episodes and injects URL slugs; `/sources` decodes an upstream response and returns it. There is no classifier, validation of filler truth or boundary detector in those functions. Thus field presence is documented; broad coverage and correctness remain unverified. [Pinned source](https://github.com/walterwhite-69/Miruro-API/blob/dfb38a646e28afa5b6f14e4b4d9d542b2bf894df/api.py#L506), [runtime endpoints](https://github.com/walterwhite-69/Miruro-API/blob/dfb38a646e28afa5b6f14e4b4d9d542b2bf894df/api.py).

Upside: AniList identity and provider-specific episode lookup. Downsides: indirect provenance, undocumented completeness, transport changes and upstream blocking. No LICENSE file was found; GitHub reports `license: null`. Last default-branch commit: 2026-07-03. [Metadata](https://api.github.com/repos/walterwhite-69/Miruro-API), [history](https://github.com/walterwhite-69/Miruro-API/commits/main/).

Recommendation: avoid as the primary filler authority; any experimental adapter should stay outside the player and retain upstream/provider identity.

## AnimeVsub organization

The org mainly publishes Vietnamese anime apps/browser tooling. Its relevant pinned repository is `anime-skip-9animetv`; this is a different project from `anime-skip/public-api`. [Organization](https://github.com/anime-vsub).

That repository documents name-based episode lookup and `/episode-skip/:ep_id` returning intro/outro. `get-source.ts` directly fetches RapidCloud `getSources`; `main.ts` tries site servers and caches nonempty ranges. It does not detect intervals from video. No filler field was found. [README](https://github.com/anime-vsub/anime-skip-9animetv), [extractor](https://github.com/anime-vsub/anime-skip-9animetv/blob/e1b1a42031d84c7b7c0ec7232d444c30702b8fa6/logic/get-source.ts), [routes](https://github.com/anime-vsub/anime-skip-9animetv/blob/e1b1a42031d84c7b7c0ec7232d444c30702b8fa6/main.ts).

Upside: small self-hostable scraper and explicit BSD-3-Clause code license. Downsides: title/name matching, provider episode IDs, upstream endpoint coupling and no guarantee that the queried media edition matches VIPTV. Last default-branch commit: 2026-03-19. The code license does not establish rights over upstream data. [License](https://github.com/anime-vsub/anime-skip-9animetv/blob/main/LICENSE), [metadata](https://api.github.com/repos/anime-vsub/anime-skip-9animetv).

Recommendation: reference implementation only; do not count it as an additional independent community timestamp database.

## AnimeThemes

The requested content index describes anime opening/ending theme resources and associations. Theme entries have an `episodes` string saying which episodes use a particular version. Video resources describe standalone theme WebMs, source edition, creditless/subbed flags and whether sequence content overlaps the episode. These fields do not provide where the theme begins or ends in a full episode, and no filler classification is documented. [Content index](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/jsonapi/reference/content/index.md), [theme entry fields](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/jsonapi/reference/content/animethemeentry/index.md), [video fields](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/jsonapi/reference/content/video/index.md).

The JSON:API is deprecated and scheduled for removal: the docs build injects that warning into every JSON:API page. Current docs also contain GraphQL and a migration guide. GraphQL documents 90 requests/minute, maximum depth 13 and query complexity 10,000. [Deprecation source](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/.vitepress/theme/jsonapi-warn-plugin.js), [migration](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/graphql/migrating/index.md), [GraphQL limits](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/graphql/intro/ratelimiting/index.md).

Upside: theme-version context and candidate audio/video references for later fingerprint experiments. Downsides: reference clips need alignment to each episode, versions may differ, and opening/ending sequences can overlap story content. Docs are MIT licensed; API usage separately applies AnimeThemes terms. Last docs commit: 2026-09-10. Do not assume the docs license licenses music or clips. [License](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/LICENSE), [API introduction and terms link](https://github.com/AnimeThemes/animethemes-api-docs/blob/main/docs/graphql/intro/index.md), [metadata](https://api.github.com/repos/AnimeThemes/animethemes-api-docs).

Recommendation: not an MVP skip-timestamp provider. Any future use belongs in an optional analysis/reference adapter with GraphQL; its `overlap` information is also a reason to require human-reviewed automatic-skip boundaries.

## Filler MVP: Jikan with provenance and overrides

Jikan's first-party OpenAPI defines `GET /anime/{id}/episodes?page=...`, returning episode `filler` and `recap` booleans plus pagination. It also defines single-episode lookup. Public limits are 3 requests/second and 60/minute. Parsed requests are cached for 24 hours; expiry/last-modified headers and ETag/If-None-Match support refresh. Upstream MAL can independently rate-limit requests. [Official OpenAPI](https://github.com/jikan-me/jikan-rest/blob/master/storage/api-docs/api-docs.json), [rendered documentation](https://docs.api.jikan.moe/#tag/anime/operation/getAnimeEpisodes).

Crucially, `EpisodeListItemParser::getFiller` returns true only when it finds MAL's Filler badge; it returns false when no badge is found. `getRecap` behaves the same way. It extracts the episode identifier from the title's episode-number cell. Therefore false means **not marked by this source**, not proven manga canon; absence, failed matching and failed fetch must remain unknown. Jikan's boolean schema cannot distinguish unannotated episodes from authoritatively non-filler episodes. [Parser](https://github.com/jikan-me/jikan/blob/master/src/Parser/Anime/EpisodeListItemParser.php#L137).

Jikan explicitly scrapes MAL, is unaffiliated with MAL, and asks consumers to respect MAL's terms. The implementation is MIT licensed and self-hostable; that does not license a derivative MAL dataset. Last REST default-branch commit: 2026-06-14. The terms URL advertised in the OpenAPI returned 404 during this research, so actual current service/data permissions still require clarification before bulk ingestion. [README and disclaimer](https://github.com/jikan-me/jikan-rest), [code license](https://github.com/jikan-me/jikan-rest/blob/master/LICENSE), [metadata](https://api.github.com/repos/jikan-me/jikan-rest).

Recommendation, inferred from these contracts: fetch through a queued backend enrichment adapter using the mapped MAL title ID and its episode numbering. Cache the source flags and observation time, follow all pages, preserve no-match/error as unknown, and label positive filler/recap flags without converting every false into “canon.” Add curated per-episode overrides and a separate classification vocabulary for mixed canon/filler if product needs it. A video detector cannot determine narrative filler merely from repeated audio or images.

## Richer filler fallback: Anime Filler List

Anime Filler List identifies itself as community-created filler lists and defines filler relative to manga. Its Naruto page distinguishes Manga Canon, Mixed Canon/Filler, and Filler. That is richer editorial classification than Jikan's two booleans. [First-party homepage](https://www.animefillerlist.com/), [Naruto example](https://www.animefillerlist.com/shows/naruto).

No supported bulk-data API, dataset license or import permission was established in this research. Recommendation: use it for authorized manual review or seek an agreed export/license; do not quietly replace a missing official API with production scraping. Preserve disagreements as source observations and let trusted local corrections win.

## Verification boundaries

Source code, first-party docs and GitHub metadata were inspected; listed dates describe default-branch commits, not uptime, maintainer capacity or guarantees. No representative cross-provider accuracy/coverage benchmark was run. A direct Jikan episode API probe could not establish live behavior from this environment; this is not proof that Jikan is down. No scraping of media or redistribution of reference clips was performed. Upstream-source edition alignment, commercial data terms and public API stability remain unresolved where explicitly indicated.
