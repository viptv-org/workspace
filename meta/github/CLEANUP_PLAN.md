# Organization-wide cleanup plan

Owner request: clean up every file and every repository in the organization. Zero functionality
change, same UI layout, fewer lines, less duplication, delete useless tests, apply only
confident performance wins.

## Guardrails (apply to every repository)

1. **No behavior change.** No public API, route, wire-schema, configuration or UI-geometry change.
   No dependency upgrades. Renderers keep the same DOM structure, class names and computed layout.
2. **Never touch pinned, vendored, generated or asset paths.** `design-contract/`, `vendor/`,
   `generated/`, `snapshot-lock.json`, `FILES.json`, packaged assets, `corpus/`, `dist/`,
   `node_modules/`. Contract imports change only through the official sync scripts.
3. **Deletion proof.** A deleted symbol must be unreferenced (or a duplicate of a live one), and a
   deleted test must be redundant, tautological, or permanently skipped. Doubt means it stays.
4. **Validation gate.** Each repository must pass its own build and full test suite *before* and
   *after* the change. A failing gate reverts that hunk; it is never absorbed by weakening a test.
5. **One commit per repository** with before/after LOC evidence and the exact validation commands.
6. **Report honestly.** Anything uncertain, hardware-dependent or unverified is listed as such
   rather than presented as covered.

## What counts as a useless test

Delete: permanently skipped/ignored cases with no documented hardware reason; tautologies that
assert a constant or the test's own construction; exact duplicates of another case's assertions;
getter/setter tests of trivial accessors; tests that only assert a mock was called as the test
itself configured it.
Keep: public behavior, error and cancellation paths, regressions with a named bug, contract and
parity evidence, and anything whose skip names a real device or platform reason.

## Waves

| Wave | Repositories | Why grouped |
| --- | --- | --- |
| W1 | web, video, tauri-video-plugin, design, .github | Light, mostly TypeScript/docs, no shared pins, parallel-safe |
| W2 | tv-web, roku | Browser and BrightScript renderers; one browser job at a time |
| W3 | backend, core | Rust; core changes regenerate bindings, so core runs after tv-web and re-syncs pins |
| W4 | android, mediamp | Kotlin/Gradle; local Gradle is memory-limited, hosted CI validates |

## Per-repository targets

| Repository | Cleanup targets | Validation |
| --- | --- | --- |
| web | duplicate API/type helpers, dead exports, redundant tests | `npm test`, `npm run build` |
| video | dead exports and duplicated constants between `guest-js`/`react`, redundant tests | `npm test`, `npm run build` |
| tauri-video-plugin | duplicated guest-js/Kotlin option plumbing, tautological unit tests, dead branches | `npm test`, `npm run build`; Kotlin via hosted build |
| design | repeated normative text across RESPONSIVE_*/TV_* specs, superseded statements left standing | doc consistency, asset/hash manifests unchanged |
| .github | duplicated policy text across AGENTS/SPEC/profile | none (docs) |
| tv-web | overlapping CSS across `tv.css`/`responsive.css`/`account-roku.css`/`guide-responsive.css`, dead responsive rules, duplicated e2e cases and platform skips, unused exports | build + strict TypeScript + design/core integrity, 121 unit tests, 115 browser cases |
| roku | duplicated helpers across `components/*.brs`, dead fields, duplicate test fixtures | `roku_build` compile, brs test suites |
| backend | duplication between `playback.rs` and `playback/direct.rs`, repeated test fixtures, redundant allocations on request hot paths | `cargo test --lib`, integration tests, strict Clippy |
| core | internal duplication in policy modules (no wire change), duplicate tests; regenerate and re-sync adopter pins | `cargo test`, Clippy, then `core-sync` into tv-web and Android |
| android | duplicated Compose theme/navigation helpers, dead screens/params, redundant instrumented tests | Kotlin compile; hosted CI |
| mediamp | duplicated player-state plumbing across modules, unused API surface, duplicate tests | Kotlin compile; hosted CI |

## Performance rules

Only changes that are provably safe and measurable in source terms: remove redundant per-request
allocations/clones, hoist repeated lookups out of render/request loops, drop duplicate work in the
same code path. No caching additions, no concurrency changes, no algorithm swaps without test
coverage for the affected path.

## Evidence to record

Per repository: commit SHA, before/after code LOC, test LOC removed, files touched, tests deleted
with the reason, tests kept, validation commands and results, and any unverified area.