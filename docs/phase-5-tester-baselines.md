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
| 5B | 2026-07-05 | 1992304+6a98dfb (staged TranscriptionService + tests) | 173 tests / 18 suites, 0 failures | ×2 (173/173) | GREEN |
| 5C | 2026-07-05 | 084ffda + staged 5C diff (SettingsForm, SettingsWindowController, SettingsWindowControllerTests) | 177 tests / 18 suites, 0 failures | ×2 (177/177) | GREEN |

5A per-suite delta vs 149/17 baseline: NEW DictionaryPromptTests=9;
CleanupLevelTests=13, CleanupServiceTests=15, SettingsStoreTests=17
(all at expected 5A counts); remaining 14 suites + 2 top-level
AppDelegate tests unchanged.

5B per-suite delta vs 5A gate: TranscriptionServiceTests 6→9 (new:
dictionaryTermsSentAsPromptField, emptyDictionaryOmitsPromptFieldEntirely,
overBudgetDictionarySendsStrictPrefixOfTerms); all other 17 suites + 2
top-level AppDelegate tests unchanged. Expected new log line during
over-budget test: `[TranscriptionService] STT prompt truncated (D59
cap)` — intentional 5B behavior, not noise.

5C per-suite delta vs 5B gate: SettingsWindowControllerTests 19→23 (new:
dictionaryTermsRoundTripThroughDraft, removingTermRemovesItOnSave,
cancelDiscardsDictionaryEdits, dictionaryOnlySaveFiresNoWarmUp); all
other 17 suites + 2 top-level AppDelegate tests unchanged. Full per-suite
counts at 5C: AppCategory 10, AudioLevel 10, CleanupLevel 13,
CleanupService 15, ConnectionProbe 12, DictationController 4,
DictionaryPrompt 9, HotkeyStateMachine 22, KeychainStore 5, MultipartBody
5, PillPanel 5, PillState 6, PillViewModel 2, SettingsStore 17,
SettingsValidation 2, SettingsWindowController 23, TranscriptionService 9,
WavEncoder 6, +2 top-level = 177.

**5C warnings:** known-noise only (NSCGS/CA + `[API] cannot add handler`
during SettingsWindowControllerTests, per registry; NSURLErrorDomain
-1001/-1004 task logs from deliberate failure-path tests; D59 truncation
log line — expected 5B behavior). No new flake entries.

**5B warnings:** known-noise only (NSCGS/CA + `[API] cannot add handler`
during GUI suites, CursorUI ViewBridge — all covered by phase-3 registry
+ 5A row). No new flake entries.

## Flake registry

Carried unchanged — see docs/phase-3-tester-baselines.md §Flake registry.
New entries land here.

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-05 | (known-noise) | `[API] cannot add handler to 2 from 2 - dropping` during SettingsWindowControllerTests | cosmetic OS log, both 5A runs, no test impact; NSCGS panel-ordering noise also observed here (registry entry says PillPanelTests — same signature) |
