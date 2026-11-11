# Fast automatic subtitle synchronization

Research coordination: [workspace #74](https://github.com/viptv-org/workspace/issues/74). Status: feasibility research; no committed product integration or deployment.

## Recommendation

Prototype a bounded native speech-activity estimator, shared in Rust, with common Kotlin owning correction state and lifecycle. Native desktop, Android and iOS analyze locally; when local access or resource budgets fail, retain original/manual timing and report unavailable. Web analysis runs on the playback gateway through the authenticated backend playback API. Fixed offset comes first; gradual drift follows after independent long-window evidence. Prioritize matching-release VOD over HTTP, torrents and HLS. Defer live and repairs for different edits.

Do not integrate AutoSubSync as the playback worker. Its current Python orchestration launches file/reference based engines and produces output files; progress callbacks are job progress, not a timestamped streaming estimator API. The UI is PyQt6 and the CLI shares that batch orchestration. Use it as a comparison tool only. [AutoSubSync source](https://github.com/denizsafak/AutoSubSync/blob/d693fd1c6391b91413aa7f1ad78b02a38ecdfe07/main/sync_core.py), [package metadata](https://github.com/denizsafak/AutoSubSync/blob/d693fd1c6391b91413aa7f1ad78b02a38ecdfe07/pyproject.toml).

## Evidence levels and source baseline

**Documentation-confirmed** describes current primary documentation/source, not execution. **Code-observed** means inspected VIPTV source. **Executed** means the exact host/fixture recorded below. **Proposed** is unmeasured.

App source was fetched and inspected from a separate detached source-only worktree at qualified main `2c579a7e2c06748061f17abac6eb4aadb44e58bf`; the retained source checkout was at `8a9a2c63` before fetching. The user-modified primary app/native/core checkout was untouched. Other read-only snapshots: core `7921f313`, gateway `b1224a76`, backend `8d995a57`, video `ffa11e26`. The gateway deployed image differs from inspected source; measurements must state the runtime image rather than imply source parity.

No Windows, macOS or iOS runtime, Apple SDK, hardware passthrough/offload, physical Android battery or browser coverage has been exercised. No Android app or Linux libmpv playback probe has run either; only the isolated Linux decoder/VAD pipeline below executed. Roku and the main PC are excluded. Context7 library resolution and documentation queries were run for Media3, AVFoundation, mpv, FFmpeg and WebRTC. The WebRTC catalog returned no native-VAD documentation; pinned primary source supplies that evidence.

## Platform feasibility

| Platform | Correction path observed in app | Audio access evidence | Feasibility / first gate |
|---|---|---|---|
| Linux desktop | libmpv; provider subtitle loaded separately; general property setter exists | Public libmpv client API controls playback but exposes no timestamped decoded-PCM callback. `audio-params` is format metadata. | Conditional. Prove a bounded nonblocking tap or bounded local audio-only decoder without another upstream reader; then test real libmpv runtime. No claim of a working PCM tap. |
| Windows desktop | Same Kotlin/libmpv adapter; packaging accepts audited ABI-2 DLL runtime | Same API limitation; runtime DLL/dependency/build versions are host-specific | Conditional. Separate Windows run must verify timestamps, seeking, passthrough, worker failure, DLL closure and resource budget. Linux results cannot qualify Windows. |
| macOS desktop | Same libmpv adapter; packaging assembles/signs private dylib closure | Same API limitation. AVFoundation APIs do not automatically solve the app's libmpv path. | Conditional. Separate Intel/Apple Silicon qualification as supported, local tap/decoder prototype and signed packaging test. |
| Android / Android TV | Media3 1.11.1, app minimum API 26; independent provider overlay queries title time every 25 ms | PCM `AudioProcessorChain` is bypassed for passthrough/offload. `ForwardingAudioSink.handleBuffer` offers buffer + PTS before the sink, which may be encoded. | Promising for PCM; encoded path is an unproven prototype. Keep playback modes intact. Inspect configured format, copy once into bounded queue, decode copied encoded access units locally if supported. |
| iOS 16–26 | AVPlayer; app Swift package minimum iOS 16 | Historical per-track MTAudioProcessingTap is available from iOS 6, but that does not establish HLS support on older systems. No generic existing-player HLS PCM route verified here. | Blocked for committed integration until local audio-access/auxiliary-decode feasibility is measured. Also implement provider-sidecar rendering/selection first. No server analysis fallback. |
| iOS 27+ | Same AVPlayer prerequisite | New AVPlayerItemSampleBufferOutput: decoded PCM, HLS only, presentation timestamps, pull/async API; iOS 27+. Expanded mixed-output HLS taps documented in 2026; FairPlay audio excluded. | Promising, unexecuted. Compile against SDK 27 with availability guards; prototype actual devices, format/timestamp/discontinuity handling and bounded lookahead. Preserve iOS 16 support. |
| Web | App wasm provider subtitles use HTMLTrackElement/TextTrack and existing timeline placement; tv-web uses video adapter tracks | Analysis belongs on gateway; browser audio capture is unnecessary | Feasible protocol extension, unimplemented. Version correction through existing authenticated playback lifecycle and retime provider cues without reloading video. Chrome/Firefox/Safari execution required. |

Documentation: [libmpv public API](https://github.com/mpv-player/mpv/blob/master/include/mpv/client.h), [mpv subtitle options](https://mpv.io/manual/master/#subtitle-options), [Media3 1.11.1 DefaultAudioSink](https://github.com/androidx/media/blob/1.11.1/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/audio/DefaultAudioSink.java), [ForwardingAudioSink](https://github.com/androidx/media/blob/1.11.1/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/audio/ForwardingAudioSink.java), [AudioSink buffer contract](https://github.com/androidx/media/blob/1.11.1/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/audio/AudioSink.java).

Code observations: [Android overlay](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/composeApp/src/androidMain/kotlin/org/viptv/app/player/Media3ProviderSubtitles.kt), [Android player](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/composeApp/src/androidMain/kotlin/org/viptv/app/player/AndroidPlaybackSession.kt), [desktop player](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/composeApp/src/desktopMain/kotlin/org/viptv/app/player/MpvPlayerSurface.desktop.kt), [iOS player](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/composeApp/src/iosMain/kotlin/org/viptv/app/player/AVPlayerSurface.ios.kt), [iOS minimum](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/iosApp/Package.swift), [wasm provider tracks](https://github.com/viptv-org/app/blob/2c579a7e2c06748061f17abac6eb4aadb44e58bf/composeApp/src/wasmJsMain/kotlin/org/viptv/app/player/BrowserProviderSubtitle.kt).

Apple's [2026 HLS update, pages 4–5](https://developer.apple.com/streaming/Whats-new-HLS.pdf) explicitly introduces decoded-audio scan-ahead and HLS mixed-output taps using `AVAudioMixInputParametersTrackMixID`. [Sample-buffer output documentation](https://developer.apple.com/documentation/avfoundation/avplayeritemsamplebufferoutput.md) specifies iOS 27+, HLS-only PCM and client-owned timebase synchronization. Bound pulling near playhead; skip zero-sample markers. [Preferred-format tap creation](https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapcreatewithpreferredformat(_:_:_:_:_:)) is iOS 27+; actual LPCM numeric type/interleaving/sample size still requires inspection. The HLS PDF does not itself specify a minimum OS for the TrackMixID constant: verify SDK header availability before implementation. FairPlay exclusion is confirmed for mixed taps; do not assume sample-buffer output exposes protected audio.

### Native access probes before integration

Android: wrap the existing audio sink rather than change decoder capabilities. In PCM mode, derive each copied span from input PTS and consumed frame count before speed/silence processors. AudioSink can partially consume a buffer and retry the same instance; copying every callback would duplicate observations. Prototype exactly-once ranges and seek/flush/configuration/output-stream-offset handling. Encoded access units need retained codec initialization, AU boundaries/batching, preroll and correct timestamp mapping; sink access does not prove an auxiliary decoder can reconstruct every codec. If unsupported or queue-full, drop analysis and mark evidence gaps. Never block the playback renderer or disable passthrough/offload to obtain samples.

Desktop: public libmpv API has no audio-output embedding. A custom mpv audio filter/fork, lavfi file/FIFO branch or custom audio output is not a proven safe public callback. FIFO/file sinks may block, remove timestamps, mutate playback mode or accumulate disk data; do not ship that assumption. First probe local buffered source access and a capped independent demux/audio-decode path using the app's retained local HTTP/torrent data. For remote HTTP/HLS, ensure byte reuse rather than silently open a second upstream reader. If no bounded local route exists, auto sync remains unavailable for that delivery.

iOS: on 27+, attach the new sample-buffer output, record output PTS and item timebase, pause pulling after a small lookahead, and fence buffer sequence changes. Compare mixed-output tap as an alternative; tap callbacks must preallocate and avoid allocation/blocking ([Apple realtime contract](https://developer.apple.com/documentation/mediatoolbox/mtaudioprocessingtapprocesscallback)). On older OS, prototype a local demux/decoder over already retained bytes only; AVAssetReader on arbitrary HLS is not established by this research. A second download is an explicit measured fallback candidate, never a hidden server analyzer. DRM bypass is excluded.

### Complete auxiliary-decode cost

Budget decoder, demux, container probing, resampling/downmix, VAD, estimator, queues, bindings and any extra cache/network reads together. PCM at 16 kHz mono s16 is 32,000 bytes/s; two seconds costs 64,000 bytes before metadata. At 48 kHz six-channel float32, two seconds is 2.304 MB; downmix promptly outside playback callbacks. Speech observations at 50 Hz are small; do not retain minutes of PCM. Decoder RSS can dominate a 64 MiB incremental budget.

A separate HTTP decoder may read multiplexed video bytes despite `-vn`; HLS with separate audio rendition can avoid that, muxed HLS cannot be assumed to. Torrent auxiliary reads can request distant pieces and compete with playback. Measure wire bytes, range/segment requests, disk IO, seeks/preroll, CPU-time per observed second, peak RSS/PSS, codec buffers, battery mWh/hour, temperature and thermal throttling. A local loopback URL is not proof of byte reuse. Stop the worker on budget breach and retain current timing.

## Estimator and confidence design (proposed)

Expose a small Rust library through existing native bindings/JNI/C ABI rather than ship Python, transcription or full language models. Feed `SpeechObservation(epoch, source_time_us, duration_us, speech_probability, quality, gap)` and immutable subtitle intervals. Return `Correction(offset_us, scale, confidence, evidence_start_us, evidence_end_us, diagnostics)`; scale initially stays 1.0. Common Kotlin owns source/track generations, manual policy, accepted state and worker cancellation. Decoder/platform adapters own timestamp normalization.

Use native WebRTC VAD as the first candidate: 16-bit mono, supported rates 8/16/32/48 kHz, 10/20/30 ms frames; 16 kHz/20 ms is a reasonable starting configuration, not an accuracy result. Preserve its BSD notices; the Python wrapper's MIT license is not the native code license. [Upstream format contract](https://github.com/wiseman/py-webrtcvad/blob/e283ca41df3a84b0e87fb1f5cb9b21580a286b09/README.rst), [full license](https://github.com/wiseman/py-webrtcvad/blob/e283ca41df3a84b0e87fb1f5cb9b21580a286b09/LICENSE). Compare a small permissive neural VAD only if dialogue/music false positives justify the runtime/model cost. No transcription required.

[ffsubsync's MIT aligner](https://github.com/smacke/ffsubsync/blob/de310ac6944b8260431a48ee741e7063cec49b0f/ffsubsync/aligners.py) supplies a useful reference: correlate binary speech/subtitle occupancy and search plausible scale factors. Its whole-reference FFT/batch behavior is not the incremental API we need. Implement independent bounded rolling windows, coarse offset search then local refinement, and score only genuinely observed overlap. Never fill unobserved gaps with silence.

Start with 30–60 s accumulated observed dialogue, bounded offset search (initial experimental ±120 s) and at most a few separated windows. Normalize scores for overlap/duty cycle; downweight sparse, extremely dense, long-duration or non-dialogue cues. Require adequate voiced duration, multiple speech onsets/cues, a clear peak margin over separated alternatives, consistent offsets across disjoint windows, and stable support after new observations. Test negative controls and permuted/null matches to calibrate acceptance. Raw correlation is not a calibrated probability. Tune on training fixtures, freeze thresholds, then report held-out coverage versus accepted-error/false-correction rates.

For drift, estimate robust local offset anchors separated over at least 10 minutes, fit an affine map with outlier rejection, require enough time leverage and tighter scale uncertainty, and restrict plausible rate ranges. Different edits, dubbing, repetitive music, sparse/forced subtitles and nonlinear offsets must abstain rather than be forced into a drift fit. Speech occupancy can align differently dubbed dialogue by accident; language/track eligibility and negative fixtures are necessary.

Bound processing with one worker, preallocated single-producer queue, small PCM/encoded queue, fixed observation horizon and capped candidate count. On overload drop analysis, invalidate affected evidence, increase sampling/backoff or stop; never propagate backpressure into playback. Queue loss is a gap, not silence.

## Timeline, state and cache protocol (proposed)

Keep canonical subtitle timing `s`, audio/title timeline `t` and player timeline `p` separate:

```
t = anchor + scale * (s - anchor) + offset
p = t - gateway_origin - player_window_origin
s_for_lookup = anchor + (t - anchor - offset) / scale
```

Positive offset displays the subtitle later. Manual delay is separately additive and wins; manual timing adjustment freezes automatic changes until explicitly resumed/reset. Seek, resume or playback-speed change never multiplies the content-time correction. Reset PCM/resampler/VAD continuity on seek or discontinuity. On source/audio/subtitle identity change, increment epoch, cancel and drain worker, discard late results; old corrections must never touch the replacement. Reuse exact-identity correction across seeks only if its confidence/evidence remain valid, and gather new evidence before revising.

For mpv provider cues already rebased by `gateway_origin = O`, desired `sub-speed = scale` needs `sub-delay = offset + (scale-1)*O` for an unanchored affine map (plus manual adjustment); simply setting both properties would rescale the removed origin. Prefer canonical cue timing where possible and test sign/order against native behavior. Android's independent overlay can instead invert the affine map for lookup; browser cues should be recomputed from canonical originals, never repeatedly transformed. Gateway caption rebasing clips cues before its origin, so apply alignment to retained canonical content before clipping rather than try to recover discarded cues from an existing SRT asset.

State: original/cached → observing → candidate → accepted or ambiguous/unavailable; manual is a separate policy. Start playback immediately on original/cached timing. Apply accepted changes atomically during a cue gap where practical, with bounded small updates and hysteresis; avoid repeated jumps. A large uncertain change stays unapplied. Audio/video playback is never restarted or replaced by a sync result.

Cache key requires exact media bytes/release, selected audio stream/codec/extradata identity, subtitle content hash, parser/normalizer version, estimator/VAD version and relevant timeline identity. Torrent infohash + exact file index/length is useful; title IDs, language, mutable URLs, duration or weak ETags alone are insufficient. Prefer a full content identity, immutable manifest root with verified segment identity, or authoritative immutable validators. A few matching sampled segments do not prove an entire release. When identity cannot be proven, keep correction session-only. Persist correction/evidence metadata, not raw audio or subtitle text; enforce TTL/size bounds. Never cache a confidence claim across a different selected audio dub.

## Web/gateway protocol and ownership (proposed)

Backend currently validates playback lease/proof and provider subtitle identity, then uploads bounded VTT content to gateway via existing authenticated caption routes. Gateway returns an immutable caption asset plus `timeline_offset_seconds`, which is timeline rebasing, not alignment confidence. Extend the existing playback snapshot/poll/event lifecycle with a versioned correction record, rather than a separate unauthenticated worker service or new video URL.

Record: `playback_generation, media_identity, audio_identity, subtitle_hash, algorithm_version, revision, offset_us, scale, anchor_us, confidence, evidence_range, state`. Browser accepts only monotonic revision matching its selected track/source generation. Server revalidates lease/profile/selection before reads and writes. Manual override is session/profile scoped as designed, never overwritten by a late worker. Expired/replaced leases cannot read another viewer's corrections.

Use one analysis job per proven exact media/audio identity; subtitle-specific correlation may reuse bounded VAD observations. Tee existing decoded audio where conversion already happens, or consume existing private replay/retained ingest data through a bounded audio-only reader. Gateway's current shared replay is explicitly a live facility: do not assume it covers all VOD HTTP/torrent paths. Map the actual VOD ingest/cache path before implementation; if reuse is unavailable, abstain rather than open an uncontrolled additional upstream reader. Analysis failure/slow output must never hold ingest or output progress.

Code observations: [backend caption validation](https://github.com/viptv-org/backend/blob/8d995a572a52345dd41a2152951eaf5dd3cb2fb5/server/src/gateway/playback_captions.rs), [gateway caption rebasing](https://github.com/viptv-org/playback-gateway/blob/b1224a76de7a2306a12aadd5f5baa1e19b1271b7/control/src/captions.rs), [shared live ingest/replay](https://github.com/viptv-org/playback-gateway/blob/b1224a76de7a2306a12aadd5f5baa1e19b1271b7/engine/src/ingest.rs).

Backend owner: authenticated protocol and identity checks. Gateway owner: bounded local audio acquisition, estimator scheduling/resources and observations. Core owner: shared estimator and generated bindings. App owner: Kotlin state, native adapters, iOS provider-rendering prerequisite and wasm cue retiming. Video/tv-web owner: corresponding adapter correction where used. Every implementation/prototype is a separately scoped repo issue/branch/PR; this research issue does not authorize product integration.

## Licensing inventory

| Component / inspected version | License evidence | Decision |
|---|---|---|
| AutoSubSync current `d693fd1c`; latest release v6.5 | LICENSE GPLv3; current pyproject explicitly GPL-3.0-or-later | Reference only; no copied integration code |
| alass `874f02d9`; alass-core 2.0.0, release v2.0.0 | LICENSE GPLv3; Cargo `GPL-3.0` | Reference/comparison only; do not infer compatible reuse |
| ffsubsync `de310ac6`; latest release 0.5.1 | MIT in LICENSE/setup metadata | Candidate algorithm reference with attribution; audit any copied files/dependencies |
| Native WebRTC VAD via pinned py-webrtcvad source | BSD-3-Clause native code, MIT wrapper | Native-only candidate; include native license/notices |
| VIPTV core | Cargo explicitly GPL-2.0-only; root GPLv2 text | GPLv3 reuse requires a deliberate compatibility decision, not an assumed upgrade |
| VIPTV gateway engine | Cargo explicitly GPL-2.0-only; root GPLv2 text | Same constraint |
| VIPTV app | Root GPLv2 text; no inspected SPDX declaration resolving “only/or later” | Confirm intended grant before third-party code reuse |
| VIPTV video | Dual MIT/Apache-2.0 license files | Keep any prototype licensing explicit |
| mpv / FFmpeg runtime | Actual builds determine GPL/LGPL and codec/dependency obligations | Record manifest/build config per platform; wrapper/header license alone is insufficient |

Primary license links: [AutoSubSync](https://github.com/denizsafak/AutoSubSync/blob/d693fd1c6391b91413aa7f1ad78b02a38ecdfe07/LICENSE), [alass Cargo](https://github.com/kaegi/alass/blob/874f02d9577182752a0f969b6d6b98fd65bdf1fc/alass-core/Cargo.toml), [ffsubsync](https://github.com/smacke/ffsubsync/blob/de310ac6944b8260431a48ee741e7063cec49b0f/LICENSE). This is an inventory and implementation constraint, not distribution/legal clearance. Neither Python packaging nor a subprocess boundary automatically resolves licensing.

## Gateway machine baseline

**Executed read-only inventory:** existing gateway host is Linux x86_64, Intel i5-9500, six physical cores, 15,300 MiB RAM. At inventory, 8,695 MiB RAM was available and 3,428/4,095 MiB swap used; that is a point-in-time shared-host observation, not isolated capacity. Existing production gateway image ID `sha256:da680d94f7a2deaca0a33b14d65f7dade7001842b877cecedab238ff8e0a6e11`, no configured container memory/CPU cap. Host FFmpeg is 8.0.1-3ubuntu2, GCC 15 build with GPL enabled; it is not yet verified equal to the gateway container's decoder. No streams or account sessions were read.

**Executed isolated mechanism baseline:** a coordinated short window permitted one container at a time, capped at one CPU, 256 MiB RAM with swap disabled, 64 PIDs, 32 MiB tmpfs, no capabilities/network and a read-only root. The production image was run as a separate temporary container, without production mounts or services. Its decoder is FFmpeg 9.0.2, GCC 14 Debian build, GPL enabled. A separate native WebRTC VAD probe was statically compiled with GCC/G++ 12.2, `-O2 -DNDEBUG -DWEBRTC_POSIX`, mode 2, 20 ms frames. The owned 20 s gated-tone/silence fixture is AAC stereo 48 kHz, 129,399 bytes. Decode, downmix and resample to mono 16 kHz s16 feed the native VAD through a pipe. Every decode/VAD run consumed 1,000 frames and exited zero. This fixture is not dialogue and supplies no alignment or confidence evidence.

| Run | Container CPU seconds | Media seconds | Worker wall seconds | Decoder peak RSS | VAD peak RSS |
|---|---:|---:|---:|---:|---:|
| Batch 1 | 0.049203 | 20 | 0.030821 | 15.88 MiB | 1.54 MiB |
| Batch 2 | 0.055867 | 20 | 0.024667 | 16.04 MiB | 1.62 MiB |
| Batch 3 | 0.049086 | 20 | 0.025367 | 16.12 MiB | 1.61 MiB |
| Input paced with `-readrate 1` | 0.626919 | 20 | 19.500511 | 16.09 MiB | 1.54 MiB |

Batch CPU was 0.00245–0.00279 CPU-seconds per media second; that is a throughput normalization, not real-time playback CPU. The single paced observation averaged approximately 3.22% of one core including container-side shell/decoder/VAD activity; FFmpeg's initial read burst makes its elapsed interval slightly under 20 s. Container creation/teardown took extra wall time and is not a player startup measurement. An isolated three-second shell-idle sample consumed 0.002349 CPU-seconds.

Separate process peaks sum to approximately 17.6 MiB in the paced run, excluding shell and any simultaneous PSS measurement. Cgroup charged-memory peak was 10.34 MiB; shared file pages can be charged elsewhere, so it must not be represented as total process RSS. Decoder and VAD child costs are included as separate measurements. External network transfer was prevented, and PCM pipe transfer was exactly 640,000 bytes. Input file IO uses the owned mounted fixture, not HTTP/torrent/HLS. No estimator, bindings, existing playback process, authenticated protocol or real playback rebuffer/startup/battery measurement is included. These results do not qualify the full resource target or any native audio-access path.

The container-cap and shared-page accounting interpretation follows [Docker resource constraints](https://docs.docker.com/engine/containers/resource_constraints/) and [runtime metrics](https://docs.docker.com/engine/containers/runmetrics/); decoder benchmarking and pacing follow [FFmpeg's CLI documentation](https://ffmpeg.org/ffmpeg.html). A complete paired gateway playback baseline remains a gate: this run did not provision an isolated authenticated playback instance with an owned full audiovisual fixture and therefore cannot report session startup or rebuffer measurements.

Recorded values and fixture/probe hashes: [machine-baseline.json](subtitle-sync/machine-baseline.json). Reproduction scripts: [build_probe.py](subtitle-sync/build_probe.py), [machine_baseline.py](subtitle-sync/machine_baseline.py), [probe source](subtitle-sync/vad_probe.c). The reusable scripts add argument validation and cleanup on timeout; only their CLI/syntax checks were repeated after those orchestration changes. No further load run was performed.

## Prototype gates and acceptance

1. **Acquisition proof per native platform.** Record exact OS, player/decoder/build versions, hardware/audio output mode and fixture identity. Demonstrate timestamped samples through HTTP/torrent/HLS, PCM and encoded modes, seeks/track changes/speed changes; force queue overload/worker death. Windows/macOS/iOS require their own execution. If auxiliary decode is necessary, include all cost categories above. A compile-only result is not audio-access proof.
2. **Estimator in isolation.** Use deterministic generated observation tests for sign, offset, affine drift, gaps, long timestamps, cancellation and generation fencing; then real speech/audio/subtitle pairs. Compare fixed-offset native estimator with pinned ffsubsync offline output; hold out titles/releases and include wrong/different releases, music/silence, dubbed audio, sparse cues and forced subtitles. Accuracy targets apply to eligible matching-release dialogue fixtures and abstention is measured separately.
3. **Gateway baseline first.** Establish current pinned runtime idle and playback-only load, then paired playback + decoder/VAD/estimator at 1/2/4 jobs with fixed one-worker caps, shared locks, bounded storage and no external provider traffic. Record startup/rebuffer/restarts, CPU-seconds, RSS/PSS, IO/network bytes and worker queue/drop counts. Reuse ingest/replay; measure added cost, not just estimator loop time. Local synthetic decode is only a lower-bound mechanism benchmark, never held-out alignment evidence.
4. **Correction during playback.** Add a scoped prototype in each owning repo only after acquisition/resources pass. Start on original/cached timing; inject accepted update without restart. Test manual freeze/reset, provider/embedded track transitions, source replacement, seek/resume/speed, timestamp origin/discontinuity, stale API revisions, worker failure and overload. Browser matrix includes current Chrome/Firefox/Safari and native-HLS Safari.
5. **Low-end and sustained qualification.** Android phones/TVs and iPhones at supported minimum/latest OS, codec/output variants and low-memory devices. Run at least 30–60 minute paired battery/thermal tests with screen/network conditions controlled; report power, throttling, CPU spikes and playback impact. Drift fixtures need at least 10 minutes. No feature-wide commitment until these results exist.

**Proposed pass targets, none achieved here:** paired added startup p95 <50 ms; zero sync-caused restarts/additional rebuffer; incremental memory <64 MiB and average CPU <10% of one core including auxiliary decode; reliable offset within 60 s observed playback for ≥90% of eligible dialogue-rich matching-release fixtures; accepted correction p95 absolute error ≤250 ms on held-out fixtures. Report sample sizes/confidence intervals and coverage; reject ambiguous/mismatched material. Drift and sustained mobile energy targets need calibration, not invented acceptance.

## Unanswered questions

- Which existing desktop local-data path can expose exact selected-audio bytes without a second upstream reader, and can it meet combined memory/CPU budgets?
- Can a Media3 sink tap reproduce correct access-unit boundaries/extradata for each passthrough/offload codec without changing playback mode? What real device limitations remain?
- Does the actual iOS SDK/toolchain expose both 2026 APIs to Kotlin/Native or require a Swift/C shim? What is the exact TrackMixID declaration availability? Which protected/non-HLS cases return no samples?
- What local acquisition route serves iOS 16–26 within network/battery budgets, and should those deliveries report unavailable until one exists?
- What exact VOD HTTP/torrent replay/cache data is reusable on gateway; what ingest routes lack it?
- Which sources provide a proven immutable media/audio identity suitable for persistent reuse? Default to session-only where absent.
- What held-out speech/music/dubbed/translation corpus and ground-truth methodology are available with redistribution/benchmark rights?
- Do confidence/coverage targets survive realistic dialogue density and subtitle paraphrasing on low-end hardware? No measured answer yet.

