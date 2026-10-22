# Source autoplay ("Best match"): prior art and a recommended model

Date: 2026-10-22. Status: research only; the design repository owns any resulting spec.

Evidence rule: every claim cites a file in a repository I read at the pinned commit shown in
the [Sources](#sources) table, or is marked **unverified**. Line numbers refer to those commits.

## Summary

1. **Nobody waits for every provider by default.** Seren stops scraping early once N sources at
   an acceptable resolution exist ("preemptive termination", default on, 5 sources) and has a
   60 s hard timeout that still plays what it has. AIOStreams exits fetching on a user
   expression evaluated at time checkpoints. VIPTV's "wait for all, and on timeout play nothing"
   is the outlier.
2. **Mature rankers are lexicographic over parsed fields, with hard filters first.** The common
   spine is: drop trash (CAM/TS/SCR, 3D), then language group, then resolution, then
   cached/instant over uncached, then HDR/codec/source type, then size or seeders. Language is
   always a group or high-weight key, never an afterthought (Torrentio, RTN +10000,
   AIOStreams `language` criterion).
3. **"Original audio" needs the title's original language.** Only AIOStreams models it: the
   preference value `Original` is resolved to the title's metadata `originalLanguage`, and
   releases whose parsed languages include it are tagged `Original`. VIPTV's `null` = "Original"
   currently means "do not rank by language at all", and VIPTV metadata has no
   original-language field.
4. **Dual/Multi/Dubbed are a separate, non-specific evidence tier, not a language.** PTT
   (`dubbed`), AIOStreams (`Dual Audio`, `Multi`, `Dubbed` listed as non-specific languages), RTN
   (`dubbed` penalty -1000 by default) and Seanime (`multipleAudioPreference`:
   neutral/prefer/avoid/only/never) all treat them as flags next to, not inside, the language
   list. Torrentio refuses to infer English from absence of markers.
5. **No tool derives device decodability automatically at the list level.** Everyone uses
   user-configured excludes (Seren `general.filters`, Umbrella `remove.*` toggles, Fen filters,
   Torrentio quality filter). Media3 and `MediaCodecList` expose what a device can decode, so
   VIPTV can do better; but release names do not carry Dolby Vision profile, so unknown must be a
   first-class state. Fallback to the next ranked source on failed start is standard in Kodi
   addons (Fen, Seren, Umbrella) and uncapped; none handle mid-playback stalls.

## Current state in VIPTV (verified earlier; not re-derived)

- Profile prefs: `preferred_audio_language: String?` (null = "Original"),
  `preferred_subtitle_language`, `source_selection: "best" | "ask"`, `max_quality_height`.
  No dub preference exists.
- Autoplay (`app/composeApp/src/commonMain/kotlin/org/viptv/app/state/ControllerCatalog.kt`,
  around line 229): with `source_selection == "best"` it waits for all providers (1 minute
  timeout; on timeout it does not autoplay), then plays `ranked.first()`. A user click cancels
  it; list navigation or focus does not.
- `rank_sources` (`backend/server/shared/engine/src/preferences.rs:94`, same in
  `core/crates/viptv-engine/src/preferences.rs`): sort key is (quality class: over cap last,
  unknown height middle; preferred-audio match; known height; highest height). Preference null
  makes the language key constant. No codec, HDR/DV, seeders, cached, size or device factor.
- `source_audio_languages` (`backend/server/shared/engine/src/stremio/source_metadata.rs:232`)
  accepts explicit provider fields and release hints; "Dual Audio", "Multi" and "Dub" are not
  recognised, and an English release with no language marker never matches "en". The doc comment
  on `rank_sources` states quality and audio metadata come "from plugins, never
  presentation-label parsing"; that rule constrains where a release-name parser may live.
- Design statements that interact with this feature:
  `design/viptv-design-system/README.md:44` ("Play starts the best source"),
  `design/viptv-design-system/notes/TV - research and decisions.md:35` ("Errors offer the next best
  source first"), `design/docs/playback/PLAYBACK_CAPABILITIES.md:11` ("Ordinary Play/Sources
  remains explicit source selection ... a failed path must ... expose retry/Choose source rather
  than silently selecting a different provider"), and the Roku contract "manual source selection
  remains manual".
- Bug that motivated this: a 4K Dolby Vision release ranks first when no cap is set and the
  Android TV emulator/TV cannot decode it.

Note the tension: `PLAYBACK_CAPABILITIES.md:11` says ordinary Play remains explicit selection,
while the design system README says Play starts the best source. The owner should reconcile
these before implementation (see Open decisions).

---

## 1. When to start, and what cancels it

### What each tool does

- **Seren (Kodi)**: setting `general.playstyleMovie`/`general.playstyleEpisodes` is "Auto Play"
  vs "Source Select"
  ([router.py:167,239](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/router.py#L167);
  labels in `strings.po` 30086/30087). Scraping has a `general.timeout` default 60 s, min 10, max 180
  ([settings.xml:1240](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/settings.xml#L1240)).
  "Preemptive termination" (`preem.enabled`, default true) ends scraping early when a count of
  filtered sources at or above a minimum resolution is reached (`preem.limit` default 5; separate
  minimum resolution for movies and TV), or immediately when a cloud/adaptive/direct source exists
  ([getSources.py:983-1030](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/getSources.py#L983)).
  Option `preem.waitfor.cloudfiles` (default false) can make it wait for the cloud-inspection
  provider first.
- **Fen Light (Kodi; unofficial mirror, see Sources)**: `results.timeout` default 60. Per-provider
  "autoplay prescrape": if the user ticked internal providers (their own cloud/cache), autoplay
  considers only those results first and falls back to the full scrape if none play
  ([sources.py:168-171, 699](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L168)).
  For next-episode autoplay it has an alert (countdown window) with a configurable
  default action on timeout: play, cancel or pause
  ([settings.py:139-147](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/settings.py#L139)).
  This is the only grace-countdown precedent found, and it applies to the next episode, not the
  first source.
- **AIOStreams**: "dynamic addon fetching" lets the user supply an exit condition expression;
  the fetcher extracts `totalTimeTaken` thresholds from it and re-evaluates the condition at
  those checkpoints so slow addons stop blocking
  ([fetcher.ts:288-320](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/streams/fetcher.ts#L288)).
  It returns a stream list; the Stremio client decides what to play.
- **Stremio**: the core has no source-picking timer. Initial source choice is a user click on the
  stream list. The automatic path is the next episode: `Settings.binge_watching` defaults to true
  ([settings.rs:15,66](https://github.com/Stremio/stremio-core/blob/c4806e8/src/types/profile/settings.rs#L15)),
  the player loads the next video's streams and picks `streams.find(is_binge_match)`
  ([player.rs:1421-1440](https://github.com/Stremio/stremio-core/blob/c4806e8/src/models/player.rs#L1421)),
  and on `Ended` the web shell navigates to the next player URL when binge is on, else goes back
  ([Player.js:229-265](https://github.com/Stremio/stremio-web/blob/9f991f0/src/routes/Player/Player.js#L229)).
  I found no first-play autoplay logic in these two repositories (absence only; not exhaustive).
- **Umbrella (Kodi)**: autoplay is sequential resolution of the ranked list with a progress dialog
  that the user can cancel (`progressDialog.iscanceled()`)
  ([sources.py:1435-1500](https://github.com/umbrellaplug/umbrellaplug.github.io/blob/cddcb7f/omega/plugin.video.umbrella/resources/lib/modules/sources.py#L1435)).
- **Seanime (anime)**: auto-select runs after the search returns; it has no countdown
  ([finder.go:36-95](https://github.com/5rahim/seanime/blob/4bdff7b/internal/torrentstream/finder.go#L36)).

### Cancel semantics

Every Kodi addon above uses a modal progress dialog whose only input is cancel; there is no
"navigation cancels" concept because there is no list on screen during autoplay. Prior art for
"focus movement in a visible list cancels the countdown" was **not found**; whatever VIPTV
chooses here is a design decision, not a precedent.

### Implication for VIPTV

- Waiting for all providers is the wrong default; the precedent is "stop when good enough" with
  a hard timeout that plays the best available rather than nothing. Today's
  "timeout means no autoplay" discards sources the user can see.
- The only visible-grace precedent is Fen's next-episode alert. A short, visible, cancellable
  countdown after an early start is consistent with it and with the Roku rule that manual
  selection stays manual.

---

## 2. Ranking: how mature tools order streams

### What each tool does

- **Torrentio** (`addon/lib/sort.js`): four modes: quality then seeders (default), quality then
  size, seeders, size
  ([sort.js:13-33](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/sort.js#L13)).
  Quality key is the resolution parsed from the stream name; any HDR/DV tag bumps it just above
  the SDR bucket of the same resolution (`replace('0p','1p')`, e.g. 1080p becomes 1081p), and
  "4k" without a number is treated as 2060p (2061p with HDR), so HDR/DV sort first within a
  resolution
  ([sort.js:112-127](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/sort.js#L112)).
  Without a debrid configured, low-seeder torrents are dropped when enough healthy ones exist
  (healthy >= 5 seeders, at least 50 results; else seeded >= 1, else top 5)
  ([sort.js:64-77](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/sort.js#L64)).
  The `qualityfilter` option *excludes* classes: BluRay REMUX, any HDR, Dolby Vision, DV+HDR,
  3D, 4k/1080p/720p/480p, "other" rips, SCR, CAM, unknown
  ([filter.js:124-239](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/filter.js#L124));
  `sizefilter` caps size ([filter.js:241](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/filter.js#L241)).
  CAM sources are labelled from the parsed `source` ([streamInfo.js:10,59-69](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/streamInfo.js#L10)).
- **AIOStreams**: a user-ordered list of criteria, each ascending or descending, with separate
  lists for movies, series and anime and for cached vs uncached
  ([sorter.ts:12-128](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/streams/sorter.ts#L12),
  [schemas.ts:1008-1027](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/db/schemas.ts#L1008)).
  Criteria: quality, resolution, language, subtitle, visualTag, audioTag, audioChannel,
  streamType, encode, size, service, seeders, private, age, addon, regexPatterns, cached,
  library, keyword, expression/regex scores, seadex, bitrate, releaseGroup
  ([constants.ts:1277-1303](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/utils/constants.ts#L1277)).
  Visual tags include `HDR10+`, `HDR10`, `DV`, `HDR`, `HLG`, `10bit`, `3D`, `IMAX`, `AI`,
  `Upscaled`, `SDR`, and derived `HDR+DV`, `DV Only`, `HDR Only`
  ([constants.ts:1181-1200](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/utils/constants.ts#L1181)),
  so it distinguishes a DV-only release from a DV+HDR10 hybrid. Each preference family exists as
  excluded / included / required / preferred lists (resolutions, qualities, languages, subtitles,
  visual tags, audio tags, channels, stream types, encodes, release groups, regex, keywords,
  seeder ranges)
  ([schemas.ts:810-880](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/db/schemas.ts#L810)).
  There is also an opt-in additive "scored sorting" model
  ([scored-sorting.mdx](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/docs/content/docs/guides/scored-sorting.mdx)).
- **RTN (Riven/Comet)**: a single additive integer. `get_rank` sums quality, HDR, channels, audio,
  codec, extras, preferred-regex (+10000) and preferred-language (+10000)
  ([ranker.py:29-59, 62-73](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/ranker.py#L29)).
  Defaults: REMUX +10000, WEB-DL +200, BluRay +100, HDTV -5000, CAM/TS/TC/SCR/R5 -10000,
  Dolby Vision +3000, HDR10+ +2100, HDR +2000, TrueHD/DTS-HD MA +2000, Atmos +1000, `dubbed` -1000
  ([models.py:267-333](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/models.py#L267)).
  A torrent below `remove_ranks_under` (default -10000) is dropped, so heavy penalties double as
  hard filters ([models.py:371-379](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/models.py#L371)).
  `sort_torrents` then orders by (resolution bucket, rank) descending, so resolution dominates
  the score ([extras.py:103-147](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/extras.py#L103)).
  Comet calls this and adds `maxResultsPerResolution`
  ([ranking.py](https://github.com/g0ldyy/comet/blob/f56677f/comet/services/ranking.py)).
- **MediaFusion**: default priority list `cached, resolution, quality, language, size, seeders,
  created_at`, each with a direction, plus a separate ordered `language_sorting`
  ([user_data.rs:25-40](https://github.com/mhdzumair/MediaFusion/blob/d033749/backend/src/models/user_data.rs#L25)).
- **Seren**: ordered sort methods from settings: quality, source type, debrid priority, size,
  low-CAM, HEVC, HDR/DV (with DV-vs-HDR order), audio channels; plus an optional first key that
  prefers releases whose title matches the last resolved release of the same show (SequenceMatcher
  ratio >= 0.85)
  ([source_sorter.py:113-154, 266-272](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/source_sorter.py#L113)).
  Size min/max filter and resolution set are hard filters
  ([source_sorter.py:52-86](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/source_sorter.py#L52)).
- **Fen Light**: choose among six orderings of (quality, provider, size); an optional "sort
  preferred filters to top" weights chosen tags (100, 50, 20, 10, 5, 2)
  ([settings.py:254-263](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/settings.py#L254),
  [sources.py:223-235](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L223)).
  Notably, display-only limits (`limit_quality_numbers`, `limit_quality_total`) are skipped when
  autoplaying ([sources.py:251,262](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L251)).
- **Seanime (anime)**: score profile with fixed bases: resolution 100 (decay 10 per rank),
  release group 50, codec 40, source type 30, language 20, multi-audio 15, multi-subs 10,
  batch 20, best-release 20, provider 5; hard "require" flags for language/codec/source; min
  seeders and size window
  ([comparison.go:15-34, 345-350, 554-590](https://github.com/5rahim/seanime/blob/4bdff7b/internal/torrents/autoselect/comparison.go#L15),
  [autoselect_types.go:6-32](https://github.com/5rahim/seanime/blob/4bdff7b/internal/library/anime/autoselect_types.go#L6)).
- **Cached vs uncached**: AIOStreams `cached` criterion and split cached/uncached lists
  ([sorter.ts:77-128, 155](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/streams/sorter.ts#L77));
  MediaFusion default key `cached` first; Fen Light never autoplays uncached results
  ([sources.py:607](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L607));
  Umbrella can remove uncached torrents (`torrent.remove.uncached`).

### Implication for VIPTV

- A lexicographic key (VIPTV's current shape) is a legitimate design; Torrentio, AIOStreams,
  MediaFusion, Seren and Fen all do it. An additive score (RTN, Seanime) is more tunable but
  hides why a source won, which matters for a visible "why this source" label. Recommendation in
  the final section stays lexicographic with hard filters first.
- Missing from VIPTV today and present in every mature tool: trash exclusion (CAM/TS/SCR/3D),
  cached/instant vs uncached, source type, HDR/DV handling, codec, size or bitrate sanity, and a
  stable tie-break.
- Resolution dominating total score (RTN `sort_torrents`, Torrentio) is the norm; language is
  either a group above resolution (Torrentio non-English) or a +10000 term that outweighs
  everything except REMUX (RTN).

---

## 3. Language and dub detection from release names

### What each tool does

- **PTT (parse-torrent-title, Python; used by RTN, Comet, Riven)**: fields `languages` (ISO 639-1
  codes, or full names with `translate_languages=True`), `dubbed: bool`, `subbed: bool`, `hdr`,
  `codec`, `audio`, `channels`, `quality`, `group`, `hardcoded`, `bit_depth`
  ([README.md:120-155](https://github.com/dreulavelle/PTT/blob/88429bb/README.md#L120)).
  `dubbed` is true for `MULTi`, `multi-audio/lang`, `dual audio/dual-audio/dual line`, bare
  `dual` not followed by `sub`, `triple audio`, `DUBBED`, `dublado`, `dubbing`, `DUBS`, `fandub`,
  and `JAP+ENG` style pairs
  ([handlers.py:606-615](https://github.com/dreulavelle/PTT/blob/88429bb/PTT/handlers.py#L606));
  `Dual-Subs` is deliberately not dubbed
  ([test_dubbed.py:14-26](https://github.com/dreulavelle/PTT/blob/88429bb/tests/test_dubbed.py#L14)).
  French markers `VF`, `VFF`, `VFQ`, `VFI`, `VF2`, `TRUEFRENCH`, `SUBFRENCH` and `VOSTFR` map to
  `fr` ([handlers.py:481-485](https://github.com/dreulavelle/PTT/blob/88429bb/PTT/handlers.py#L481)):
  note `VOSTFR` means original audio with French subtitles, yet PTT adds `fr` to `languages`, so
  `languages` mixes audio and subtitle evidence. `languages` is not set for bare `MULTi` (tests
  expect `[]` for "MULTi" with no list,
  [test_language.py:156-165](https://github.com/dreulavelle/PTT/blob/88429bb/tests/test_language.py#L156)).
  **Unverified**: whether PTT recognises flag emoji; I found no emoji handling in `handlers.py`.
- **guessit**: `language` (audio) and `subtitle_language` are separate properties resolved via
  babelfish; tags like `VOSTFR` and `MULTi` are recognised, and `Dual Audio` is an `other` value
  ([languages.md:32-39](https://github.com/guessit-io/guessit/blob/3c73072/docs/languages.md#L32),
  [options.json:462-470, 510](https://github.com/guessit-io/guessit/blob/3c73072/guessit/config/options.json#L462)).
  guessit separates audio from subtitle language, which PTT does not.
- **Torrentio**: parses with PTT, merges torrent-name, file-name and provider languages; for
  anime it adds a `dubbed` label and hides `japanese`; if the only language is English it hides
  languages entirely; non-anime with no language but `dubbed` shows `dubbed`
  ([streamInfo.js:71-91](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/streamInfo.js#L71)).
  Labels are `Dubbed`, `Multi Audio`, `Multi Subs`, `Dual Audio` or a flag emoji, written into
  the stream `title`
  ([languages.js:1-48](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/languages.js#L1)).
  Its language sort works by substring-matching the selected language's flag emoji in the
  title ([languages.js:69-71](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/languages.js#L69));
  English is intentionally never filtered or promoted: "No need to filter english since it's
  hard to predict which entries are english"
  ([sort.js:36-44](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/sort.js#L36)).
  Consequence: Torrentio's `Dubbed`/`Dual Audio` labels never match a selected language.
- **AIOStreams**: its own regex table plus a fork of PTT. Language values include `Multi`,
  `Dual Audio` (`dual[ .-_]?(audio|lang(uage)?|flac|ac3|aac2?)`), `Dubbed` (`dub(s|bed|bing)?`),
  and named languages incl. `Portuguese (Brazil)`
  ([regex.ts:146-160](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/parser/regex.ts#L146));
  `dubbed` is a separate boolean ([file.ts:159](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/parser/file.ts#L159)).
  `['Unknown', 'Dual Audio', 'Multi', 'Dubbed']` are explicitly "non-specific": a stream with
  only those can have a real language *inferred* from a matched localized title or episode title,
  and English (and Japanese for anime) is never inferred
  ([filterer.ts:810-846](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/streams/filterer.ts#L810)).
  The `Original` preference value resolves to the title's metadata original language, and streams
  whose parsed languages include it are tagged `Original`
  ([filterer.ts:1560-1567](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/streams/filterer.ts#L1560),
  [formatters/base.ts:466-482](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/formatters/base.ts#L466)).
- **RTN**: uses PTT output. `language_handler` order: unknown and `remove_unknown_languages` ->
  drop; `required` languages with none present -> drop; English accepted when
  `allow_english_in_languages` (default true); any `allowed` language bypasses exclusion;
  any `exclude` language -> drop
  ([fetch.py:121-170](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/fetch.py#L121)).
  Ranking: +10000 if any `preferred` language is in `languages`; `dubbed` -1000
  ([ranker.py:69-73, 258-259](https://github.com/dreulavelle/rank-torrent-name/blob/bdb9973/RTN/ranker.py#L69)).
  So RTN's default is "penalise dubbed, reward preferred language".
- **Comet**: `ensure_multi_language` prepends `multi` to `languages` when there is more than one
  language or `dubbed` is true
  ([parsing.py:112-127](https://github.com/g0ldyy/comet/blob/f56677f/comet/utils/parsing.py#L112)),
  and renders `multi` with a globe emoji commented "Dubbed"
  ([languages.py:4](https://github.com/g0ldyy/comet/blob/f56677f/comet/utils/languages.py#L4)).
- **Seanime**: `containsMultiOrDual` treats any audio term containing `multi`, `dual` or `dub` as
  "multiple audio", exposed as a five-state preference neutral/prefer/avoid/only/never, separate
  from the ordered `preferredLanguages` list
  ([comparison.go:154-162, 174-182](https://github.com/5rahim/seanime/blob/4bdff7b/internal/torrents/autoselect/comparison.go#L154),
  [autoselect_types.go:15-18](https://github.com/5rahim/seanime/blob/4bdff7b/internal/library/anime/autoselect_types.go#L15)).
  It cannot tell "dub only" from "dual audio".
- **Hayase/Miru**: release notes mention UI indicating dub/sub support via extensions; I found no
  documented audio-language default (**unverified** beyond that; source is a third-party release
  mirror, not read from the repo).

### Implication for VIPTV

- Adopt a three-way split of evidence instead of one `audio_languages` list:
  `languages_explicit` (ISO tags/flags/names), `multi_or_dual` (Dual/Multi/Dubbed flag with unknown
  language set) and `subtitle_hints` (VOSTFR, hardsub, multisub). Mixing `VOSTFR` into audio
  languages (PTT) produces wrong "fr audio" matches.
- Because `rank_sources`'s doc says metadata must come from plugins, not label parsing, the
  release-name parser (PTT-equivalent) should be a named plugin/normalizer step in the engine
  whose output is typed fields, with the raw label never inspected in ranking. This keeps the
  existing rule while giving ranking the fields it needs.
- English absence-of-marker should not match "en" automatically (Torrentio, AIOStreams both
  avoid it), but the "original" preference can treat unmarked as probably original; this is the
  tier model proposed in the final section.

---

## 4. Device decode capability

### What each tool does

- **No list-level auto-detection found** in Torrentio, AIOStreams, Comet, MediaFusion, RTN, Seren,
  Fen Light, Umbrella or Seanime. Everything is user-configured:
  - Seren: `general.filters` string, default `3D,AV1`
    ([settings.xml:1552-1556](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/settings.xml#L1552));
    separate DV and HDR switches; a **HYBRID** release (DV with an HDR10 base) is *not* removed
    when only DV is disabled, and removed only if both are disabled
    ([source_sorter.py:42-86](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/source_sorter.py#L42)).
  - Umbrella: toggles `remove.dolby.vision`, `remove.hdr`, `remove.hevc`, `remove.av1`,
    `remove.avc`, `remove.cam.sources`, `remove.3D.sources`, and per-audio-codec removals
    (opus, DD, DD+, Atmos, TrueHD, DTS, DTS-HD, DTS-HD MA)
    ([settings.xml:1928-2072](https://github.com/umbrellaplug/umbrellaplug.github.io/blob/cddcb7f/omega/plugin.video.umbrella/resources/settings.xml#L1928)).
  - Fen Light: an HEVC filter with a configurable maximum quality (HEVC results above that
    quality are removed, e.g. allow HEVC up to 1080p but not 4K), with a separate maximum for
    autoplay vs listing, and DV/HDR filters with the same hybrid exception
    ([sources.py:210-221](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L210)).
  - Torrentio `qualityfilter`: exclude HDR, DV, DV+HDR, 4k
    ([filter.js:124-170](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/filter.js#L124)).
  - AIOStreams: excluded/preferred `encodes`, `visualTags`, `audioTags`, with the
    `DV Only`/`HDR+DV` derived tags
    ([schemas.ts:850-868](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/db/schemas.ts#L850)).
  - RTN gives `hevc`/`av1` positive default scores (+500) and codec-agnostic rank for DV; nothing
    device-aware.
- **Android, what a client can query** (this is where VIPTV can exceed the prior art):
  - Display side: `Display.getHdrCapabilities().supportedHdrTypes` (`HDR_TYPE_DOLBY_VISION` since
    API 24); `getSupportedHdrTypes` deprecated in API 34 in favour of
    `Display.Mode.getSupportedHdrTypes()`
    ([Display.HdrCapabilities](https://developer.android.com/reference/android/view/Display.HdrCapabilities),
    [HDR video playback](https://developer.android.com/media/grow/hdr-playback); the latter says an
    app needs "a HDR-capable decoder and ... a HDR-capable display" and only demonstrates the
    HLG display check and `MediaCodecList.findDecoderForFormat` with an AV1 Main10 profile key).
  - Decoder side: `MediaCodecList(REGULAR_CODECS).findDecoderForFormat(format)` returns null when
    no codec supports the format (same HDR page). Media3 wraps this in
    `MediaCodecInfo.isFormatSupported`, documented as "whether the decoder may support decoding
    the given format both functionally and performantly"
    ([MediaCodecInfo.java:276-283](https://github.com/androidx/media/blob/8c6678b/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/mediacodec/MediaCodecInfo.java#L276)).
  - Fallback knowledge in Media3: for Dolby Vision it will substitute the HEVC decoder for some
    profiles (`DolbyVisionProfileDvheDtr`, `DvheSt`), H.264 for `DvavSe`, AV1 for `Dvav110`, but
    *not* for `DolbyVisionProfileDvheStn` (not backward compatible) and `DvheDtb` (deprecated, not
    always backward compatible); DTS-HD falls back to DTS core; E-AC3-JOC to E-AC3
    ([MediaCodecUtil.java:379-420](https://github.com/androidx/media/blob/8c6678b/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/mediacodec/MediaCodecUtil.java#L379)).
    The mapping of constant names to the common "profile 5/7/8" numbers is **unverified** here
    (from general Dolby naming); confirm before using numbers in UI.
  - A release name rarely states the DV profile. Torrentio and AIOStreams expose only "DV" and
    whether HDR is also present, so a source's DV profile is unknown until the file is probed.
  - Design repo already states emulators are not evidence of codec support
    ([PLAYBACK_CAPABILITIES.md:101](../../design/docs/playback/PLAYBACK_CAPABILITIES.md)).

### Implication for VIPTV

- Capability must be a *client-reported input* to ranking (the Android TV app knows; the backend
  does not). Three states per attribute: supported, unsupported, unknown.
- The prior art's best heuristic is the hybrid distinction: DV together with an HDR/HDR10 marker
  usually still plays as HDR10 on non-DV hardware; "DV only" is the risky class. Both Torrentio
  and AIOStreams surface this. Rank "DV only" down (or out) unless the device reports a DV decoder.
- Emulator and software decoders can report support but be unusably slow; the
  `isFormatSupported` "performantly" check and a startup-failure fallback (section 5) together cover
  it.

---

## 5. Fallback on failure, undecodable or stall

### What each tool does

- **Fen Light**: `play_file` builds an ordered attempt list (starting source, then the rest, then
  earlier ones reversed unless `limit_resolve`), a numbered resolver dialog shows
  `NN. provider | quality | size | info | name` per attempt, and success is "playing, total time
  known, fullscreen video active"; otherwise it advances to the next item, with a skip control and
  cancel, and after the last item it stops and shows `playback_failed_action`
  ([sources.py:601-690](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/sources.py#L601),
  [player.py:38-56](https://github.com/kornbred/plugin.video.fenlight/blob/HEAD/resources/lib/modules/player.py#L38)).
  No try cap.
- **Seren**: `resolve_multiple_until_valid_link` iterates the sorted sources until one resolves
  to a link; exceptions are logged and skipped
  ([resolver/__init__.py:42-61](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/resolver/__init__.py#L42)).
  It handles resolve failures, not playback failures.
- **Umbrella**: `sourcesAutoPlay` loops the list with a progress dialog; skips URLs that do not
  look playable ([sources.py:1465-1490](https://github.com/umbrellaplug/umbrellaplug.github.io/blob/cddcb7f/omega/plugin.video.umbrella/resources/lib/modules/sources.py#L1465)).
- **Stremio**: no automatic next-source on failure found in core or web; the user returns to the
  stream list (**unverified** beyond absence in these two repositories).
- **Media3** distinguishes failure causes useful for deciding when to advance:
  `ERROR_CODE_DECODER_INIT_FAILED` 4001, `DECODER_QUERY_FAILED` 4002, `DECODING_FAILED` 4003,
  `DECODING_FORMAT_EXCEEDS_CAPABILITIES` 4004, `DECODING_FORMAT_UNSUPPORTED` 4005
  ([PlaybackException.java:261-276](https://github.com/androidx/media/blob/8c6678b/libraries/common/src/main/java/androidx/media3/common/PlaybackException.java#L261)).

### Implication for VIPTV

- Auto-advance on failed start is the norm in Kodi addons; none do mid-stream stall switching, and
  none cap tries. Caps matter more for VIPTV because each attempt can cost a gateway ingestion
  job and a viewer lease (playback-gateway), unlike a Kodi resolve call.
- The user must see each attempt (Fen's numbered line is the model).
- This collides with `PLAYBACK_CAPABILITIES.md:11` ("rather than silently selecting a different
  provider"): "silently" is the operative word; a visible, labelled auto-advance in an
  autoplay session the user opted into is arguably compliant, but the owner should confirm.

---

## 6. Per-title memory

### What each tool does

- **Stremio** defines `behaviorHints.bingeGroup`: "if defined, addons with the same
  `behaviorHints.bingeGroup` will be chosen automatically for binge watching"
  ([stream.md, behaviorHints](https://github.com/Stremio/stremio-addon-sdk/blob/master/docs/api/responses/stream.md)).
  `is_binge_match` requires both groups defined and equal
  ([stream.rs:141-150](https://github.com/Stremio/stremio-core/blob/c4806e8/src/types/resource/stream.rs#L141)).
  The same document also lists `notWebReady` ("needs to be set to true if the URL does not
  support https or is not an MP4 file") and `proxyHeaders`, relevant to playability but not to
  ranking.
  For continue-watching, the core looks back up to 30 videos from the current one for the last
  stored stream item
  ([streams_bucket.rs:33-55](https://github.com/Stremio/stremio-core/blob/c4806e8/src/types/streams/streams_bucket.rs#L33)),
  then finds a matching stream from the same addon by equality, else by `bingeGroup`
  ([meta_details.rs:917-1000](https://github.com/Stremio/stremio-core/blob/c4806e8/src/models/meta_details.rs#L917)).
  Track state carried within a binge group: embedded subtitle track and an audio track *only if it
  has a language to validate*; delays are dropped; across unrelated streams only playback speed
  and player type survive
  ([streams_item.rs:61-125](https://github.com/Stremio/stremio-core/blob/c4806e8/src/types/streams/streams_item.rs#L61)).
  I found no consumer of `last_used_stream` in stremio-web (it may be used by other shells;
  **unverified**).
- **What addons put in bingeGroup** (so what "the same" means in practice):
  Torrentio series: `torrentio|<quality>|<hdr>|<release group>` when episode info matches the
  torrent, else the infohash; movies: quality, source, codec, bit depth, HDR
  ([streamInfo.js:134-148](https://github.com/TheBeastLT/torrentio-scraper/blob/3c84f67/addon/lib/streamInfo.js#L134)).
  Language and dub are **not** in Torrentio's group, so a sub release and a dub release of the same
  group/quality collide. Comet: `comet|<service>|<infohash>`
  ([stream.py:449,501](https://github.com/g0ldyy/comet/blob/f56677f/comet/api/endpoints/stream.py#L449)).
  AIOStreams makes it configurable: method `matchingFile`, `matchingIndex` or `firstFile`, with
  default attributes resolution, quality and release group, selectable from service, cached,
  addon, proxied, resolution, quality, encode, audioTags, visualTags, languages, releaseGroup,
  type, infoHash, size
  ([utils.ts:6-95](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/transformers/utils.ts#L6),
  [constants.ts:1102-1127](https://github.com/Viren070/AIOStreams/blob/454e8b4/packages/core/src/utils/constants.ts#L1102)).
- **Umbrella** stores an explicit per-show per-season preference (infohash + debrid) only for
  season/show packs, and on the next episode first filters the list to that hash and autoplays it,
  falling back to normal selection if it is gone
  ([source_preferences.py:20-100](https://github.com/umbrellaplug/umbrellaplug.github.io/blob/cddcb7f/omega/plugin.video.umbrella/resources/lib/modules/source_preferences.py#L20),
  [sources.py:264-272](https://github.com/umbrellaplug/umbrellaplug.github.io/blob/cddcb7f/omega/plugin.video.umbrella/resources/lib/modules/sources.py#L264)).
- **Seren**: optional first sort key by similarity to the last resolved release title of the same
  show (stored per `trakt_show_id`)
  ([helpers.py:52](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/helpers.py#L52),
  [source_sorter.py:130-135, 266-272](https://github.com/nixgates/plugin.video.seren/blob/b4f4b63/resources/lib/modules/source_sorter.py#L130)).
- **Jellyfin** remembers the user's chosen *track index* per item when `RememberAudioSelections`
  is on and the index is still valid; otherwise falls to preference
  ([MediaSourceManager.cs:531-545](https://github.com/jellyfin/jellyfin/blob/08c2ba6/Emby.Server.Implementations/Library/MediaSourceManager.cs#L531)).
  **Plex**: a manual track choice for an item in a personal library overrides auto-selection and
  is not changed again (from Plex's [Account Audio/Subtitle Language Settings](https://support.plex.tv/articles/204985278-account-audio-subtitle-language-settings/);
  direct fetch returned 403, so this is a search-result summary: treat as **unverified** wording).

### Implication for VIPTV

- Memory is a *soft* signal that outranks the global ranking but never overrides hard filters:
  Stremio matches an exact source then a group; Seren sorts it first; Umbrella pins a hash.
- Remember attributes (group, resolution, language class, source type), not only an infohash,
  because the next episode is usually a different file. Language and dub must be in the memory
  key (Torrentio's bingeGroup omits them, so VIPTV should not rely on addon bingeGroup alone).
- Track-level memory (audio track language) is separate and already modelled by Stremio
  (`language` required to carry an audio track id across streams).

---

## Plex, Jellyfin and anime-specific audio preference models

- **Jellyfin** (server-side track default): user `AudioLanguagePreference` may be the literal
  `OriginalLanguage`, which is resolved from the item's inherited original language; with
  `PlayDefaultAudioTrack` it prefers the file's default-flagged track; otherwise it uses the
  first match, scored by language-preference index
  ([MediaSourceManager.cs:531-585](https://github.com/jellyfin/jellyfin/blob/08c2ba6/Emby.Server.Implementations/Library/MediaSourceManager.cs#L531),
  [MediaStreamSelector.cs:14-29, 181-190](https://github.com/jellyfin/jellyfin/blob/08c2ba6/Emby.Server.Implementations/Library/MediaStreamSelector.cs#L14)).
  Subtitle "Smart" mode only shows subtitles when the chosen audio language is not one of the
  preferred subtitle languages
  ([MediaStreamSelector.cs:60-72](https://github.com/jellyfin/jellyfin/blob/08c2ba6/Emby.Server.Implementations/Library/MediaStreamSelector.cs#L60)).
  Jellyfin has no dub concept: dub vs sub is just which language wins.
- **Plex** (summary via search; direct fetch blocked): "Automatically Select Audio and Subtitle
  Tracks" must be on; first track matching the preferred audio language wins, else the first
  unknown-language track, else a lone track; manual selections stick. Whether Plex offers an
  "original language" value is **unverified** (not in the pages found).
- **Media3** (what the Android client player can consume): `setPreferredAudioLanguages` and
  `setPreferredAudioRoleFlags` on `DefaultTrackSelector`, and `C.ROLE_FLAG_DUB` ("track is in a
  different language from the original, for example dubbed audio")
  ([DefaultTrackSelector.java:397-410](https://github.com/androidx/media/blob/8c6678b/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/trackselection/DefaultTrackSelector.java#L397),
  [C.java:1595-1599](https://github.com/androidx/media/blob/8c6678b/libraries/common/src/main/java/androidx/media3/common/C.java#L1595)).
  If the gateway emits HLS/DASH with audio renditions it can tag dubs with this role.
- **Anime**: Seanime models "multi/dual audio" as a five-state preference and language as an
  ordered list (above). Torrentio treats anime specially (hides Japanese, labels `dubbed`).
  AIOStreams has per-type (movies/series/anime) sort lists. No tool found models "sub" as a
  first-class value; sub is the default and dub is the marked exception.

Implication: model *original* (resolved from metadata, as Jellyfin and AIOStreams do) separately
from *named language*, and treat dub as the marked deviation from original rather than as a
language.

---

## Recommended model (recommendation, not a decision)

### A. When autoplay starts

1. Collect candidates as providers stream in (VIPTV already publishes partial results).
2. Hard filters apply continuously (section C); only survivors count.
3. **Start conditions (first to fire):**
   - all providers finished; or
   - **early start**: a survivor exists that satisfies the user's must-haves (language tier A,
     within cap, decodable-known or unknown, cached/instant) and a grace window of about 2 s
     since the latest improvement has passed; or
   - hard timeout (suggest 20 s for first result, keep 60 s only as the provider ceiling): play the
     best survivor available; only if there are none, show the list and "Choose source".
4. Show a visible countdown/label ("Playing best match: <provider> <res> <lang> in 2...") with
   Cancel and Choose source. A better candidate arriving during grace replaces the target and does
   not extend past the hard timeout.
5. **Cancels autoplay**: explicit click/OK on a row, Back, opening the source sheet or filters,
   any D-pad move or scroll in the list that the user initiated. Does not cancel: initial focus
   placement, re-ranking caused by newly arrived sources, window focus changes. (Prior art has
   no list-navigation precedent; this matches the Roku "manual selection stays manual" rule.)
6. With `source_selection = "ask"` nothing auto-starts.

### B. Ranking (ordered key; lower is better; ties fall to the next key)

Hard filters first (removed from autoplay; still listed, greyed, in manual mode):
CAM/TS/TC/SCR/R5/telesync; 3D; known-undecodable video (device capability); size over a
sanity ceiling; uncached torrents that fail the seeder floor (autoplay only).

Then:

1. Decode class: known-decodable < unknown < risky (e.g. "DV only" on a device without DV).
2. Language tier (section C) for the active audio preference.
3. Resolution cap class (existing): within cap < unknown height < over cap.
4. Availability: cached/direct/instant < uncached torrent (autoplay never picks uncached).
5. Resolution, highest first, bounded by the cap.
6. Dynamic range supported by display+decoder: HDR10/HLG/DV-with-HDR10-base/supported DV > SDR >
   unsupported.
7. Source type: REMUX > BluRay > WEB-DL > WEBRip > HDTV/other rips (RTN order; RTN penalises
   WEBRip -1000 and HDTV -5000).
8. Video codec preference: hardware-decodable codecs first (AVC/HEVC; AV1 only with a decoder).
9. Audio codec decodability: demote TrueHD/DTS-HD MA/Atmos when no passthrough (Media3 can fall
   back DTS-HD to the DTS core and E-AC3-JOC to E-AC3, so these are demotions not exclusions).
10. Bitrate or size within a target band (not "largest wins"; Seren and Seanime both bound size).
11. Memory bonus (section F): matches last-used group/resolution/language class for this series.
12. Seeders (uncached only), preferred release group, provider order, then input order (stable).

Rationale for order: language and decodability above resolution matches Torrentio (language
group first) and RTN (+10000 language), and directly addresses the 4K DV bug without needing a
manual cap.

### C. Language and dub model

Preference fields (proposed profile shape; today: `preferred_audio_language: String?`):

- `audio_language`: `"original"` or a BCP-47 tag (e.g. `"en"`, `"ja"`). Make `original` an
  explicit value; keep `null` as "no preference". Needs the title's original language from
  metadata (not present in VIPTV today: open decision 3).
- `dub_policy` (applies when the chosen language differs from the title's original, or to avoid
  dubs): `avoid` | `allow` | `prefer`. Default `avoid` for `original`, `allow` otherwise.
- `multi_audio`: `neutral` | `prefer` | `avoid` (Seanime's idea, but only these three; "only/never"
  is better expressed as filters).
- Optional per-type overrides, since anime preferences diverge (AIOStreams has movies/series/
  anime lists): `audio_language_anime`, `dub_policy_anime`.

Evidence tiers per release for a requested language L (O = title original language):

| Tier | Meaning | Source evidence |
|---|---|---|
| A | audio explicitly includes L (and for L=original, not "dubbed only") | explicit ISO/flag/name |
| B | Dual/Multi/Dubbed flag with unknown language set; may contain L | `dubbed`, `Multi`, `Dual Audio` |
| C | no language marker | (for `original`: probably original; for other L: unknown) |
| D | explicit languages that exclude L | e.g. "FRENCH" when L = en |

Order: A < B < C < D for L != original; for `original`: A and C (unmarked) tie as best, B next,
D last, with `dub_policy = avoid` additionally sinking releases flagged `dubbed` without O.
Dual/Multi audio containing L is not a language mismatch but implies the player must pick the
track: after start, select by language (Media3 preferred audio language; Stremio carries audio
track id only with a language).

Parsing: a normalizer step (plugin-side, preserving the `rank_sources` "no label parsing in
ranking" rule) emitting `audio_languages`, `multi_or_dual`, `dubbed`, `subtitle_hints`
(`VOSTFR`, hardsub, multisub). Reuse PTT's rules (`handlers.py:606-615`, French at `481-485`) as
the reference; do not copy its audio/subtitle conflation of `VOSTFR`. Flag emoji from Torrentio
titles should be parsed explicitly (PTT has none), mapping the table at `languages.js:1-48`.
Never infer English from absence (Torrentio, AIOStreams).

### D. Capability filtering

- Client reports `DeviceCapabilities` with the ranking request: per codec (avc, hevc, hevc-main10,
  av1, vp9) max decodable height at 30/60 fps from `MediaCodecList.findDecoderForFormat` plus a
  Media3-style functional+performance check; display HDR types from `Display.Mode`; DV decoder
  present or not; audio decode/passthrough (AC-3, E-AC-3, E-AC-3 JOC, TrueHD, DTS, DTS-HD).
- States are tri-valued (supported / unsupported / unknown); unknown ranks between.
- Derive a default `max_quality_height` from the device when the profile has none, so 4K on a
  1080p-only decoder is never first.
- Treat emulators and software-decoder-only devices conservatively (design already says
  emulators prove nothing).
- Per-profile user overrides remain (exclude HEVC, HDR, DV, AV1), as in Seren and Umbrella.

### E. Fallback policy

- Auto-advance only inside an autoplay session the user opted into, and only on start failure:
  decoder init/format (Media3 4001, 4004, 4005), gateway/transport error, or no first frame
  within a startup timeout (suggest 15 s).
- Up to 3 attempts, each shown ("Source 1 failed: unsupported video. Trying next: ..."), with Skip
  and Stop. After the cap, stop on the source list with the failures annotated and "Retry" and
  "Choose source" (the `PLAYBACK_CAPABILITIES.md` wording).
- Remember the failed source for the session and demote its codec class for later ranking in that
  session (e.g. one DV decode failure demotes other DV-only sources).
- Never auto-advance from a manual selection.
- Mid-playback stall: do not switch sources (no prior art); offer Retry/Choose source.

### F. Per-series memory

- Store per (profile, series) after a successful start: release group, resolution class,
  language tier/dub flag, source type, video codec class, and the exact infohash/URL for pack
  continuity.
- Next episode: apply as ranking key 11 (soft); if a `bingeGroup` from the same addon exists and
  matches, prefer it only among survivors of hard filters. Include language/dub in the match
  because Torrentio's group omits it.
- Reset on manual selection of a different source for that series (new choice replaces memory).
- Carry the audio-track language between episodes (Stremio behaviour), dropping sync delays.

### Open decisions for the owner

1. **Contract conflict**: is "Best match" autoplay allowed to start a source and auto-advance
   (README "Play starts the best source", TV note "Errors offer the next best source first") given
   `PLAYBACK_CAPABILITIES.md:11` ("Ordinary Play/Sources remains explicit source selection")?
2. **Grace window and early-start threshold**: grace length, hard timeout (current 60 s), and
   whether a countdown is shown or autoplay is instant after early start.
3. **Original language data**: add `original_language` to metadata (needs a provider that
   supplies it) before `audio_language = original` can mean anything; until then it stays
   "no preference".
4. **Dub model scope**: only `dub_policy`, or also per-type (anime) overrides; default for anime
   (original + subs vs English dub).
5. **Where the release-name parser lives** (engine normalizer vs plugin), given the
   "never presentation-label parsing" rule, and which parser rules to adopt (PTT-equivalent).
6. **Capability reporting**: who computes `DeviceCapabilities` (KMP app per platform), how
   non-Android platforms report, and whether the gateway can transcode or remux undecodable
   sources (not investigated here), which would change "exclude" to "convert".
7. **Fallback**: attempt cap (3?), startup timeout, whether any auto-advance is permitted on TV
   and web, and how failures are shown.
8. **Cancel-on-navigation**: whether D-pad focus movement or only activation cancels autoplay on
   TV.
9. **Memory scope**: per profile and per series, and whether it persists across devices
   (server-side) or is local.
10. **Uncached torrents**: never autoplay them, or allow with a seeder floor.

---

## Sources

Read at these commits (short hashes; clones taken 2026-10-22). Primary sources only except where
marked.

| Name | Repository | Commit |
|---|---|---|
| Stremio addon SDK | [Stremio/stremio-addon-sdk](https://github.com/Stremio/stremio-addon-sdk) | master (docs/api/responses/stream.md) |
| stremio-core | [Stremio/stremio-core](https://github.com/Stremio/stremio-core) | c4806e8 |
| stremio-web | [Stremio/stremio-web](https://github.com/Stremio/stremio-web) | 9f991f0 |
| Torrentio | [TheBeastLT/torrentio-scraper](https://github.com/TheBeastLT/torrentio-scraper) | 3c84f67 |
| AIOStreams | [Viren070/AIOStreams](https://github.com/Viren070/AIOStreams) | 454e8b4 |
| RTN 1.11.1 | [dreulavelle/rank-torrent-name](https://github.com/dreulavelle/rank-torrent-name) | bdb9973 |
| PTT | [dreulavelle/PTT](https://github.com/dreulavelle/PTT) | 88429bb |
| Comet | [g0ldyy/comet](https://github.com/g0ldyy/comet) | f56677f |
| MediaFusion | [mhdzumair/MediaFusion](https://github.com/mhdzumair/MediaFusion) | d033749 |
| guessit | [guessit-io/guessit](https://github.com/guessit-io/guessit) | 3c73072 |
| Seren | [nixgates/plugin.video.seren](https://github.com/nixgates/plugin.video.seren) | b4f4b63 |
| Umbrella | [umbrellaplug/umbrellaplug.github.io](https://github.com/umbrellaplug/umbrellaplug.github.io) | cddcb7f |
| Fen Light | [kornbred/plugin.video.fenlight](https://github.com/kornbred/plugin.video.fenlight) | HEAD at 2026-10-22; **unofficial mirror**, the author's own repository is archived (RPDevs-Vault/FenlightAnonyMouse.github.io); treat Fen Light claims as secondary |
| Jellyfin | [jellyfin/jellyfin](https://github.com/jellyfin/jellyfin) | 08c2ba6 |
| Seanime | [5rahim/seanime](https://github.com/5rahim/seanime) | 4bdff7b |
| Media3 | [androidx/media](https://github.com/androidx/media) | release branch 8c6678b |
| Android docs | [HDR video playback](https://developer.android.com/media/grow/hdr-playback), [Display.HdrCapabilities](https://developer.android.com/reference/android/view/Display.HdrCapabilities) | fetched 2026-10-22 |
| Plex | [Account Audio/Subtitle Language Settings](https://support.plex.tv/articles/204985278-account-audio-subtitle-language-settings/) | direct fetch 403; search summary only |

Not verified from a primary source: Hayase/Miru audio defaults; Plex "original language"
option; PTT emoji handling; Stremio first-play autoplay in other shells; DV constant-to-profile
number mapping; Fen Light behaviour at the author's own canonical repository.
