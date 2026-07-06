# Tester baselines — LotusScribe (Phase 8)

> Last gate's counts + flake registry. Archives: docs/phase-0…7-tester-
> baselines.md (phase-3 holds the full flake registry table).

## Baseline carried into Phase 8

**Commit:** e9f53a7 (post-Phase-7; Phase-7 human legs still open).
**Counts:** 218 tests in 22 suites, 0 failures. Flake sweep 2026-07-05:
10× consecutive green, zero flakes.
**Test command:** `make test` — run TWICE per gate.

**Carried concurrency surface:** dedicated URLProtocol stubs
(TranscriptionServiceTests, ConnectionProbeTests, CleanupServiceTests);
UUID-suffixed UserDefaults suites; R41/R44 warmUp: stubbing. 8A note:
CleanupServiceTests key-set tripwire (`Set(json.keys) ==
["model","messages","temperature"]`) MUST update when 8A adds the
thinking parameter — expect it to gain the new key conditionally on the
reasoning-toggle setting. 8B note: warm-up trigger moves onto the
recording path — any DictationController warm-up test must stub the
network.

**Environment facts carried:** macOS 26 Tahoe; personal-team signing;
Input Monitoring + Accessibility granted. vLLM UP; serves 6 models
(Qwen3.6 FP8/NVFP4, Phi-3.5-mini ×2, whisper-large-v3, claude-opus) —
eviction/cold-reload is the suspected #16 cause 8B mitigates.

## Phase 8 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 8A   | 2026-07-06 | e9f53a7 + staged 8A diff (4 src + 3 test) | 223 tests / 22 suites, 0 failures | ×2 | PASS both runs |
| 8B   | 2026-07-06 | 93ff403 + staged 8B diff (DictationController.swift + DictationControllerTests.swift) | 226 tests / 22 suites, 0 failures | ×2 | PASS both runs |

**8A per-suite delta vs 218 baseline (+5 total, exactly as reviewer/engineer expected):**
SettingsStoreTests 19→21 (+2), CleanupServiceTests 15→17 (+2),
SettingsWindowControllerTests 26→27 (+1). All other 19 suites unchanged.
Key-set tripwire updated as required: cleanup body asserts
`["model","messages","temperature","reasoning_effort"]` with toggle ON
(default) and the original 3-key set with toggle OFF; warm-up body
carries `reasoning_effort` too (D72). Warnings: only the registered
known-noise `xcodebuild: WARNING: Using the first of multiple matching
destinations` (phase-2/3 registry). No compiler warnings, no new flakes.

**8B per-suite delta vs 223 (8A) (+3 total, exactly as expected):**
DictationControllerTests 4→7 (+3): new `recordWarmUpFiresWhenNeverFired`,
`recordWarmUpSuppressedInsideWindow`, `recordWarmUpFiresAtWindowBoundary`
(all exercise the pure debounce predicate `shouldFireRecordWarmUp(now:last:)`
— no network touched, satisfying the 8B carried note by construction
rather than by stubbing). All other 21 suites + the
2 top-level tests (appDelegateInitializes, mainMenuRoutesPaste) unchanged.
Warnings: registered known-noise only — destination auto-pick (phase-3
registry) and NSCGS/CA-commit during SettingsWindowControllerTests ×6
(phase-3 registry). No compiler warnings, no new flakes. Cross-check:
matches reviewer's 226/22 ×1 at APPROVED.

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry
+ phase-5/6 additions. New entries land here.
