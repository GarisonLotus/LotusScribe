# Tester baselines — LotusScribe (Phase 5)

> Last gate's counts + flake registry. Archives: docs/phase-0…4-tester-
> baselines.md (phase-3 holds the full flake registry table).

## Baseline carried into Phase 5

**Commit:** 8f063c5 (4C; Phase-3 + Phase-4 close gates still OPEN —
BLOCKED-BATCH in when-vllm-is-back.md).
**Counts:** 149 tests in 17 suites, 0 failures, green ×2.
**Test command:** `make test` — run TWICE per gate.

**Carried concurrency surface:** serialized suites with dedicated
URLProtocol stubs — TranscriptionServiceTests, ConnectionProbeTests,
CleanupServiceTests; UUID-suffixed UserDefaults suites. R41/R44: any new
SettingsWindowControllerTests MUST stub `warmUp:` (default = real
network). Phase-5 note: dictionary injection touches BOTH
TranscriptionService (Whisper `prompt` field) and CleanupService (system
prompt) — deltas ride both existing stub surfaces.

**Environment facts carried:** macOS 26 Tahoe; personal-team signing
(5RC66Q82V9); Input Monitoring + Accessibility granted; tap `defaultTap`
at launch; mic prompt at first recording start.
**Endpoint status: vLLM host UNREACHABLE (2026-07-05)** — all
dictation-dependent human verifies recorded in when-vllm-is-back.md.

## Phase 5 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 5A | 2026-07-05 | 8f063c5 | 170 tests / 18 suites, 0 failures | ×2 (170/170) | GREEN |

5A per-suite delta vs 149/17 baseline: NEW DictionaryPromptTests=9;
CleanupLevelTests=13, CleanupServiceTests=15, SettingsStoreTests=17
(all at expected 5A counts); remaining 14 suites + 2 top-level
AppDelegate tests unchanged.

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry.
New entries land here.

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-05 | (known-noise) | `[API] cannot add handler to 2 from 2 - dropping` during SettingsWindowControllerTests | cosmetic OS log, both 5A runs, no test impact; NSCGS panel-ordering noise also observed here (registry entry says PillPanelTests — same signature) |
