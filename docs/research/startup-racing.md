# Racing two sources at startup: measured

Date: 2026-11-06. Status: research only; the design repository owns any resulting spec.

Question (design#142 decision 4): for a start whose target is a torrent, or a provider
with a high recent startup failure rate, does opening the next best row in parallel and
playing whichever reaches a frame first cut time-to-first-frame enough to pay for the
extra bandwidth and connections?

## Summary

1. **The ranked top two are always torrents.** In all 30 titles the top three ranked
   rows were Torrentio torrents; the second best was never an HTTP row. "Race only
   torrents" is therefore "race every start" with this provider mix.
2. **Racing torrents buys little and costs a lot.** Median start fell from 4.01 s to
   3.32 s (−0.46 s, −11 %) and p90 did not move (7.84 s to 7.85 s). Six of 30 titles got
   at least 1 s slower. A race used 1.85× the bytes and 1.93× the peak sockets of a
   single start.
3. **Racing removed the observed start failures.** Single starts produced no frame in
   3 of 90 attempts (3.3 %); races failed 0 of 90. A failed single start costs the 20 s
   deadline plus the 2 s notice plus the next row's start (about 27 s).
4. **The second row is often genuinely faster, but not predictably.** In 12 of 30 titles
   the second row's median start beat the first's (by 3.45 s); racing those gained 2.59 s.
   In the other 18 racing lost 0.36 s median, and 6 of the 30 titles were ≥1 s slower with
   a race than without one.
5. **A flaky direct/HTTP provider is where racing pays.** 21 % of that add-on's ranked
   rows delivered no media bytes at all, its first working row started at 4.43 s median
   (12.16 s p90), and racing its top two working rows gained 1.25 s median and 3.40 s p90
   with no ≥1 s regressions and about one extra player connection.

Recommendation: **do not race torrent starts; race only a direct/HTTP start whose provider
has a high recent startup failure rate**, and only once the client records that rate.
Details under [Recommendation](#recommendation).

## What was measured

All times are wall clock on this host, one session, against a throwaway backend bound to
loopback with a fresh SQLite database and its own local owner account, and two public
add-ons: Torrentio for torrents and NoTorrent (community directory, public) for direct
HTTP/HLS rows. No existing account or profile data and no provider credential were used.

- **Resolve**: `POST /api/streams` to the last provider answer (discovery complete),
  including the engine's parse, release facts and hard filters.
- **Admission**: `POST /api/playback` to `status: ready`, including the native torrent
  grant. This is server work and does not touch the swarm.
- **Prebuffer**: torrent worker `prepare` to a media URL (metainfo, peers, head pieces).
- **First bytes**: for HTTP rows, a `Range: bytes=0-1023` GET through the add-on redirect
  (`time_starttransfer`); for torrents, the moment the prebuffer produced a media URL.
- **First frame**: from `loadfile` to mpv's `playback-restart` event, with mpv idle and
  configured like the desktop client (`cache=yes`, 64 MiB demuxer cache, 10 s readahead,
  `vo=null`, `ao=null`, `hwdec=auto-safe`). Player startup is excluded; mpv is warm.
- **Single**: the ranked best match only, which is the client's default. Failures are
  counted per attempt; the shipped fallback's cost is computed from the second row's own
  measurement (20 s deadline, 2 s notice, next row).
- **Race**: ranked best match and second best opened together; the first frame wins and
  the other row's player, torrent worker and playback lease are cancelled at that frame.
- **Bytes**: interface receive counter over the whole trial, so both racers count.
- **Sockets**: peak simultaneous sockets owned by the trial's player and torrent worker,
  sampled every 100 ms. The torrent worker's peers are mostly short-lived connection
  attempts (SYN-SENT bursts of up to ~175), so this counts connection churn, not steady
  peer count (about 13 established).

Requests were paced: one discovery per title, at most six range GETs for the HTTP rows and
one HTTP add-on fetch, each seconds apart because the trials between them take seconds;
the torrent swarm traffic is the client's own.

Torrent trials used a fresh worker and a fresh piece cache, and the measurement was always
cold. The sample is 20 movies and 10 episodes (first episode of ten series), 30 titles,
median 98 candidate rows per title. Each title ran: the first-ranked row twice, the second
twice, the third once, and two races (90 singles per row column, 90 races). A second
bandwidth pass added one single for each of the first two rows and one race with bytes and
sockets sampled from the same start point. Trials were shuffled within each title.

One title (Stranger Things S1E1) returned zero rows from both add-ons and was replaced with
Friends S1E1; it is not in the sample.

## Results

### Discovery is not the bottleneck

| | median | p90 |
| --- | ---: | ---: |
| Resolve, 30 titles | 0.20 s | 0.24 s |

Both add-ons answered in about 0.18–0.20 s (median) for a fully cached, popular title. The
start phase (admission, prebuffer, player) is 20× the discovery cost, so a race of two rows
changes nothing before the start.

### Torrent starts (Torrentio)

| Condition | median | p90 | no frame |
| --- | ---: | ---: | ---: |
| Single, best match | 4.01 s | 7.84 s | 3 of 90 |
| Single, second row | 5.13 s | 15.23 s | 1 of 90 |
| Race, best match + second | 3.32 s | 7.85 s | 0 of 90 |
| Ideal race (min of the two singles) | 3.17 s | 6.67 s | — |

Paired per title, single − race: median **+0.46 s**, p90 **+3.70 s** (positive means racing
was faster; quartiles: 0.66 s slower to 2.58 s faster). Racing was ≥1 s faster
on 11 titles and ≥1 s slower on 6. The second row won 11 of 30 races. The measured race was
within 0.5 s of the ideal min(row 1, row 2) on 17 of 30 titles, and 3 races were more than
0.5 s slower than both singles (two swarms competing on one host).

Where the start time goes (median, bandwidth pass):

| Phase | Single | Race winner |
| --- | ---: | ---: |
| Admission (grant) | 0.06 s | 0.06 s |
| Torrent prebuffer | 0.58 s | 0.52 s |
| Player to first frame | 2.72 s | 2.01 s |

The player phase dominates. Racing can only shorten the prebuffer and the part of the
player phase spent waiting for pieces, which bounds the gain well below the 4 s median.

### Cost of racing torrents

| | Single | Race | Ratio (median per title) |
| --- | ---: | ---: | ---: |
| Bytes, median | 12.9 MB | 21.5 MB | 1.85× |
| Bytes, p90 | 27.2 MB | 40.3 MB | — |
| Peak sockets, median | 192 | 375 | 1.93× |

No race opened two rows with the same info hash, so the duplicate-release waste is not
counted here; when it does happen it doubles the cost for no chance of a faster frame. The
worst observed race downloaded 157 MB before the winner's first frame.

### Failures and fallback

Three of 90 single attempts on the best match produced no frame within 20 s, and the second
row failed once in 90. The failures were season packs (The Matrix once, Succession twice;
Succession framed once in three attempts, so its single figure is that one success). With
the shipped fallback such a start costs the deadline plus the 2 s notice plus the next row's
start, about 27 s. Racing removes exactly that case (0 failures in 90), which is its clearest
benefit, but the fallback already covers it at 3.3 % of starts.

### Direct/HTTP rows (HTTP add-on)

The HTTP rows are HLS delivered by third-party hosts through the add-on's redirect. They
never entered the ranked top three: 30 of 30 titles ranked Torrentio torrents first. The
throwaway backend has no playback gateway, so its `/api/playback` refuses direct delivery
(`gateway_required`); these rows were played from the add-on's own URL, which is the same
URL the backend would have handed over.

| | value |
| --- | ---: |
| Ranked HTTP rows that delivered media bytes (1 KiB range GET) | 283 of 360 (79 %) |
| First-byte time on those rows, median | 3.40 s |
| Single, first working row: median / p90 | 4.43 s / 12.16 s |
| Single, second working row: median / p90 | 8.05 s / 11.73 s |
| Race of both working rows: median / p90 | 2.47 s / 9.85 s |

Racing the two working rows against starting the first: median **1.25 s**, p90 **3.40 s**;
16 of 30 titles ≥1 s faster, none ≥1 s slower. Bytes fell from 5.4 MB to 4.1 MB (the slow
single reads far more before its first frame); sockets went from 4 to 5 median.

The 21 % dead-row rate is the main finding for this class: the provider's ranked rows are
often 404/502/paywall, so the client regularly spends the 20 s deadline and falls back. The
rows themselves are also slow (median first byte 3.4 s), which is what makes a second row
attractive.

### Per-title results

`Single` is the best-match start, `Race` the measured race of the top two, `Ideal` the
lower of the two rows' single medians, `HTTP single`/`HTTP race` the direct rows above,
and the last two columns the bytes downloaded by the bandwidth-pass single and race.

| Title | Kind | Resolve | Single | Race | Ideal | HTTP single | HTTP race | MB single | MB race |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| The Shawshank Redemption | movie | 0.19 | 2.37 | 2.85 | 2.37 | 10.66 | 9.80 | 1.6 | 15.2 |
| The Godfather | movie | 0.22 | 5.31 | 3.04 | 5.31 | 1.57 | 1.45 | 7.6 | 26.8 |
| The Dark Knight | movie | 0.22 | 1.82 | 1.45 | 1.82 | 13.46 | 5.02 | 12.9 | 13.9 |
| The Godfather Part II | movie | 0.23 | 7.86 | 4.32 | 3.14 | 1.66 | 1.55 | 25.4 | 40.3 |
| Schindler's List | movie | 0.23 | 4.05 | 3.48 | 3.69 | 12.67 | 4.75 | 35.7 | 25.6 |
| The Lord of the Rings: The Return of the King | movie | 0.23 | 3.86 | 3.16 | 3.86 | 1.70 | 1.53 | 13.0 | 21.4 |
| Pulp Fiction | movie | 0.15 | 7.14 | 4.23 | 0.85 | 10.37 | 9.23 | 14.2 | 14.0 |
| The Lord of the Rings: The Fellowship of the Ring | movie | 0.18 | 7.51 | 0.79 | 1.50 | 12.88 | 8.61 | 22.5 | 0.7 |
| Forrest Gump | movie | 0.20 | 12.54 | 16.61 | 4.76 | 11.76 | 9.29 | 10.3 | 28.7 |
| The Matrix | movie | 0.13 | 17.28 | 9.19 | 9.20 | 10.26 | 10.29 | 16.7 | 21.7 |
| The Lord of the Rings: The Two Towers | movie | 0.25 | 3.96 | 1.38 | 1.37 | 1.55 | 1.50 | 16.4 | 32.9 |
| Inception | movie | 0.16 | 0.99 | 1.43 | 0.99 | 11.69 | 9.07 | 5.8 | 156.8 |
| Star Wars: Episode V - The Empire Strikes Back | movie | 0.21 | 2.21 | 2.49 | 2.21 | 9.96 | 9.55 | 9.6 | 24.3 |
| Fight Club | movie | 0.20 | 3.72 | 3.16 | 2.01 | 10.92 | 7.62 | 9.5 | 2.2 |
| Goodfellas | movie | 0.18 | 0.91 | 1.08 | 0.91 | 1.62 | 1.52 | 10.4 | 2.1 |
| One Flew Over the Cuckoo's Nest | movie | 0.24 | 7.84 | 2.72 | 7.84 | 6.40 | 6.41 | 13.1 | 29.7 |
| Se7en | movie | 0.18 | 3.47 | 7.68 | 3.47 | 12.11 | 11.15 | 3.9 | 13.8 |
| The Silence of the Lambs | movie | 0.23 | 7.47 | 8.25 | 7.47 | 9.50 | 9.39 | 5.9 | 16.9 |
| It's a Wonderful Life | movie | 0.23 | 6.46 | 3.88 | 2.15 | 1.70 | 1.54 | 12.7 | 34.1 |
| Spirited Away | movie | 0.20 | 2.69 | 0.92 | 0.85 | 10.87 | 10.35 | 14.8 | 8.8 |
| Breaking Bad | episode | 0.16 | 1.90 | 4.01 | 1.90 | 3.58 | 1.51 | 2.5 | 11.0 |
| Game of Thrones | episode | 0.22 | 3.20 | 2.96 | 3.20 | 3.65 | 1.46 | 8.5 | 31.0 |
| The Office | episode | 0.17 | 6.40 | 7.80 | 6.40 | 3.27 | 1.39 | 17.0 | 28.8 |
| The Wire | episode | 0.21 | 4.65 | 7.30 | 4.65 | 3.51 | 3.40 | 27.2 | 70.0 |
| Better Call Saul | episode | 0.13 | 6.58 | 7.11 | 6.58 | 3.67 | 1.49 | 1.8 | 10.0 |
| Chernobyl | episode | 0.26 | 5.16 | 4.29 | 5.16 | 3.78 | 1.39 | 23.8 | 11.1 |
| Succession | episode | 0.19 | 4.83 | 2.10 | 2.39 | 2.85 | 1.48 | 28.7 | 27.3 |
| The Last of Us | episode | 0.18 | 3.13 | 3.79 | 2.81 | 4.29 | 1.43 | 11.5 | 54.6 |
| House of the Dragon | episode | 0.21 | 3.94 | 1.90 | 3.94 | 4.57 | 1.41 | 15.1 | 15.2 |
| Friends | episode | 0.14 | 3.47 | 4.65 | 3.47 | 3.54 | 1.42 | 81.3 | 12.4 |

## Limitations

- **One host, one network, one session.** Contention between simultaneous torrent swarms
  is real on this VPS (3 races were slower than both singles); a client with more headroom
  might capture more of the ideal min. Nothing here measures a TV, a phone or a debrid link.
- **Cold cache only.** Every torrent trial used a fresh worker cache, which is the first
  play of a title. A warm piece cache would make both conditions faster and could shrink
  the prebuffer part of the gain.
- **Popular titles.** The sample is well-seeded movies and first episodes, median 98 rows.
  Obscure titles fail more often and slower, which is exactly where a race looks better
  than these numbers. The 3.3 % failure rate is a floor, not a population estimate.
- **No debrid rows.** With no debrid credential allowed, the "HTTP/debrid" class is a
  public HLS provider. Cached debrid links are the case the numbers do not cover; they
  should behave like the fastest HTTP rows (1.5–4 s) where a race has little to recover.
- **The measured race is not the client's race**: both rows were opened by the harness with
  the same admission, grant and player calls, and the loser was cancelled at the winner's
  first frame. It does not include the client's 1.5 s grace window, its UI or its own
  cancellation timing.
- **20 s first-frame deadline** (the direct-source deadline). A torrent that would have
  framed at 22 s is counted as a failure; the client's torrent runtime has its own
  deadline.
- The host ran other builds during parts of the session; per-trial variance is large
  (identical rows ranged 0.8–17 s), which is why each head row was measured three times.

## Recommendation

1. **Do not race torrent starts.** The design's "race only torrents" branch fires on every
   start observed here (top three rows always Torrentio torrents) and buys 0.46 s median,
   no p90, and 6 of 30 titles slower, for 1.85× bytes and 1.93× connections. Keep the
   single start and the existing fallback for torrents.
2. **Race only a direct/HTTP start whose provider has a high recent startup failure rate.**
   That is the one place the data supports it: a 21 % dead-row rate, a 4.4 s first working
   row, and 1.25 s median / 3.4 s p90 recovered with no ≥1 s regressions and one extra
   connection. Gate it on the provider's measured recent failures, not on delivery type.
   The client does not record per-provider startup outcomes yet, so this needs that signal
   first; until then the fallback covers the same failures.
3. **Keep the fallback either way.** Racing had zero failures in 90 attempts, but a race
   cannot help when both rows are bad, and the torrent case it would rescue is 3.3 % of
   starts.

No implementation issue is filed: the data rejects the torrent branch of design#142
decision 4, and the flaky-provider branch needs a failure-rate signal that does not exist
yet. The spec should drop "or a torrent" before anything is built.

## Data

- `startup-racing/trials.csv`: every trial, one row each: condition, slot or winner,
  resolve, admission, prebuffer, first frame, bytes, peak sockets, error.
- `startup-racing/summary.json`: per-title medians and the aggregates above.
- `startup-racing/harness.py`, `measure.py`, `summarize.py`: the harness. It needs a
  throwaway backend (fresh database, `viptv-server create-admin`, the two add-ons
  installed), the app's pinned torrent worker, mpv and curl.