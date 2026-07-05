# Tester baselines — LotusScribe (Phase 3)

> Last gate's counts + flake registry. Archives: docs/phase-0/1/2-tester-
> baselines.md (full phase-1 empirical record in phase-1; phase-2 gate
> history in phase-2).

## Baseline carried into Phase 3

**Commit:** e6b6fe6 (Phase 2 close — human gate passed 2026-07-05).
**Counts:** 80 tests in 12 suites, 0 failures, green ×2 (phase-2
waveform-fix gate; per-suite breakdown in phase-2 baselines).
**Test command:** `make test` — run TWICE per gate; carried concurrency
surface: serialized TranscriptionServiceTests + URLProtocol global handler.
3A note: ConnectionProbeTests will join that same serialized/global-handler
surface — watch for cross-suite handler bleed at the 3A gate.

**Environment facts carried:** macOS 26 Tahoe; stable personal-team signing
(5RC66Q82V9) — TCC grants persist across rebuilds (Q1/Q2 closed); Input
Monitoring + Accessibility granted; tap mode `defaultTap` at launch under
existing grants (Q5 record); mic prompt fires at first recording start, not
launch. STT endpoint live: https://vllm.garison.com/v1/audio/transcriptions,
model whisper-large-v3, no key (D13).

## Phase 3 gates

| gate | date | staged base | counts | runs | result |
|------|------|-------------|--------|------|--------|
| 3A | 2026-07-05 | e79d800 (staged, not committed) | 89 tests / 13 suites | ×2 | green ×2, 0 failures |
| 3B | 2026-07-05 | 4b3aa9d (staged, not committed) | 106 tests / 15 suites | ×2 | green ×2, 0 failures |
| 3C | 2026-07-05 | 537f174 (staged, not committed) | 120 tests / 15 suites | ×2 | green ×2, 0 failures |

**3A per-suite breakdown (89 = 87 in-suite + 2 top-level):**
AudioLevelTests 10, ConnectionProbeTests 7 (new), DictationControllerTests 4,
HotkeyStateMachineTests 22, KeychainStoreTests 5, MultipartBodyTests 5,
PillPanelTests 5, PillViewModelTests 2, SettingsStoreTests 6,
SettingsValidationTests 2, SettingsWindowControllerTests 7 (+2 net),
TranscriptionServiceTests 6, WavEncoderTests 6, top-level (no suite) 2
(appDelegateInitializes, mainMenuRoutesPaste). Delta vs 80/12 baseline:
+7 (new ConnectionProbeTests suite) +2 (SettingsWindowControllerTests) = 89/13,
matching engineer claim.

**3A concurrency watch:** no cross-suite URLProtocol stub race observed —
TranscriptionServiceTests and ConnectionProbeTests both clean in both runs
(ConnectionProbeTests uses its own URLProtocol stub). Remains a watch item,
not an incident.

**3A warnings:** known-noise only (destination auto-pick, NSCGS/CA during
PillPanelTests, task-name-port, CursorUI ViewBridge). No new entries.

**HUMAN-AT-SCREEN:** spec §3A verify items 2–5 **PASSED** (2026-07-05,
orchestrator-recorded from user at-screen report at 638b11d — sheet
labels renamed Save Anyway / Try Again before the verify): success flow
(spinner → checkmark → ~2 s auto-close → persisted), failure sheet both
buttons per D37, mid-test close writes nothing, D38 dictation
regression clean. **3A CLOSED at 638b11d; code baseline 89/13.**

**3B per-suite breakdown (106 = 104 in-suite + 2 top-level):**
AudioLevelTests 10, CleanupLevelTests 6 (new), CleanupServiceTests 11 (new),
ConnectionProbeTests 7, DictationControllerTests 4, HotkeyStateMachineTests 22,
KeychainStoreTests 5, MultipartBodyTests 5, PillPanelTests 5,
PillViewModelTests 2, SettingsStoreTests 6, SettingsValidationTests 2,
SettingsWindowControllerTests 7, TranscriptionServiceTests 6, WavEncoderTests 6,
top-level (no suite) 2 (appDelegateInitializes, mainMenuRoutesPaste). Delta vs
89/13 baseline: +6 (new CleanupLevelTests) +11 (new CleanupServiceTests) =
106/15, matching engineer claim.

**3B watch items — both clean:** (1) UserDefaults bleed: CleanupServiceTests
uses a UUID-suffixed suite; SettingsStoreTests 6/6 green in both runs, no
intermittents. (2) Launch warm-up guard: the four `[CleanupService] warm-up`
log lines in the run output all occur strictly inside CleanupServiceTests'
own stub-driven tests (warmUpRequestMatchesSpec,
warmUpRetriesOnceWithoutKeepAliveOnNon2xx, warmUpSkippedWhenNotEnabled); no
CleanupService lines at hosted-app launch or anywhere outside the suite —
XCTestSessionIdentifier guard held, no real network fired during tests.

**3B warnings:** known-noise only (destination auto-pick, NSCGS/CA during
PillPanelTests, task-name-port, CursorUI ViewBridge, SettingsWindowController
show() debug logs). No new entries.

**3B CROSS-CHECK:** parallel-mode — orchestrator collates; reviewer 106/15
inlined: MATCHED (tester independent ×2: 106 tests / 15 suites, green both).

**HUMAN-AT-SCREEN (3B): PASSED-PRIMARY** (2026-07-05,
orchestrator-recorded). Verify 2 (real endpoint, filler sentence
cleaned) user-confirmed at 2083eb0.Warm-up legs verified from logs:
launch skip-guard fired live (settings empty at launch; cleanup still
worked via the live-settings read), HTTP-400 -> retry-sans-keep_alive
leg observed in hosted tests.Negative paths (dead-host verify 3,
level-off verify 4) user-waived ("continue") — both unit-covered (D43
fallback, isEnabled). **3B CLOSED at 2083eb0.**

**3C per-suite breakdown (120 = 118 in-suite + 2 top-level):**
AudioLevelTests 10, CleanupLevelTests 6, CleanupServiceTests 11,
ConnectionProbeTests 12 (+5: llmSucceedsOn200WithChatCompletionJSON,
llmRequestMatchesSpec, llmNon200FailsWithStatusInReason,
llmMissingChoicesFails, llmInvalidURLFailsWithoutNetwork),
DictationControllerTests 4, HotkeyStateMachineTests 22, KeychainStoreTests 5,
MultipartBodyTests 5, PillPanelTests 5, PillViewModelTests 2,
SettingsStoreTests 7 (+1: llmModelRoundTrips), SettingsValidationTests 2,
SettingsWindowControllerTests 15 (+8: cleanupLevelRoundTripsThroughDraft,
emptyLLMURLSkipsLLMProbe, sttFailureStopsChainBeforeLLMProbe,
llmFailureNamesEndpointAndWritesNothing, bothProbesGreenPersistsAndSucceeds,
llmChangeSaveFiresWarmUpOnce, noChangeSaveFiresNoWarmUp,
reentrantSaveCancelsStaleAutoClose), TranscriptionServiceTests 6,
WavEncoderTests 6, top-level (no suite) 2 (appDelegateInitializes,
mainMenuRoutesPaste). Delta vs 106/15 baseline: +5 ConnectionProbeTests
+1 SettingsStoreTests +8 SettingsWindowControllerTests = 120/15, matching
engineer claim (106 + 14).

**3C R41 watch — CLEAN:** the default warm-up closure (real network) is not
exercised by any test. All four `[CleanupService] warm-up` log lines in the
full run-2 log occur strictly inside CleanupServiceTests' own stub-driven
tests (warmUpRequestMatchesSpec, warmUpRetriesOnceWithoutKeepAliveOnNon2xx,
warmUpSkippedWhenNotEnabled). The SettingsWindowControllerTests warm-up
tests (llmChangeSaveFiresWarmUpOnce, noChangeSaveFiresNoWarmUp) emitted zero
CleanupService lines — injected counter path only. No outbound-host strings
(vllm/garison) and no connection-failure noise anywhere in the log. Run 1
tail consistent (no CleanupService lines in the settings-tests region).

**3C cross-suite stub isolation:** clean — TranscriptionServiceTests,
ConnectionProbeTests, CleanupServiceTests all green both runs, no
URLProtocol handler bleed observed.

**3C warnings:** known-noise only (destination auto-pick, NSCGS/CA during
PillPanelTests, task-name-port, CursorUI ViewBridge, SettingsWindowController
show() debug logs). No new entries.

**3C CROSS-CHECK:** parallel-mode — orchestrator collates; reviewer 120/15
inlined: MATCHED (tester independent ×2: 120 tests / 15 suites, green both).

**HUMAN-AT-SCREEN (3C): PENDING** — spec §3C verify items 2–5: (2) level
Picker selection persists across settings reopen, (3) dual-probe failure
sheet names the failing endpoint (STT vs LLM), (4) warm-up-on-endpoint-change
log line observed on real Save with changed LLM endpoint, (5) D38 dictation
regression clean + 390 pt window fit (no clipping/scroll).

## Flake registry (known-noise, carried from phase 2)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `appintentsmetadataprocessor … Metadata extraction skipped. No AppIntents.framework dependency found.` (×2) on builds that relink | link-time tool noise; xcresult warnings block stays empty |
| 2026-07-04 | (known-noise) | `xcodebuild: WARNING: Using the first of multiple matching destinations` | tool notice; benign destination auto-pick |
| 2026-07-04 | (known-noise) | `[Common] Unable to obtain a task name port right for pid NNN: (os/kern) failure (0x5)` at hosted-app launch | cosmetic, intermittent |
| 2026-07-05 | (known-noise) | `[NSCGS] Warning: Invalid attempt to open a new transaction during CA commit` + `[NSCGS] Ignoring request to entangle context after pre-commit` during PillPanelTests | cosmetic AppKit/CA panel-ordering logs |
| 2026-07-05 | (known-noise) | `[CursorUI] ViewBridge to RemoteViewService Terminated: ... NSViewBridgeErrorCanceled` at hosted-app run | cosmetic; message self-describes as benign |
