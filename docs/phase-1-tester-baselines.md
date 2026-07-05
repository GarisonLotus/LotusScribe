# Tester baselines — LotusScribe (Phase 1)

> Last gate's counts + flake registry. Phase-0 archive:
> docs/phase-0-tester-baselines.md.

## Last gate

**Sub-phase:** Phase-1 close (HEAD cf5471c)
**Test command:** `make test` — run TWICE.
**Counts (both runs):** 51 tests in 8 suites, 0 failures, both runs
`** TEST SUCCEEDED **`, zero `warning:` lines in run-2 log grep.
- Matches the last reviewer run exactly (51/8 expected); no count drift.
  Delta vs the 1E tester baseline below (45/7) is the post-1E growth already
  accounted for by the reviewer's run at cf5471c.

### 1E archive

**Sub-phase:** 1E
**Test command:** `make test` — run TWICE (carried concurrency surface:
serialized TranscriptionServiceTests + URLProtocol global handler); both runs
identical (test/suite event sequence diff-identical after timing strip).
**Counts (both runs):** 45 tests in 7 suites, 0 failures, 0 build warnings.
Run 1 was incremental/no-compile (no warning evidence), so tester touched the
3 delta files (mtime only) before run 2; run 2 compiled exactly
SettingsWindowController.swift, StatusItemController.swift,
SettingsValidationTests.swift and its xcresult build summary is clean —
0 errors / 0 warnings / 0 analyzer warnings; xcresult test summary
45 total / 45 passed / 0 failed / 0 skipped.
- HotkeyStateMachineTests: 14 · WavEncoderTests: 6 · SettingsStoreTests: 6 ·
  KeychainStoreTests: 5 · MultipartBodyTests: 5 · TranscriptionServiceTests: 6
  · SettingsValidationTests: 2 (new — acceptsHTTPAndHTTPSURLsWithHost,
  rejectsNonHTTPSchemesAndHostlessStrings) · smoke appDelegateInitializes: 1
  (freestanding — runner reports 7 suites)
- Matches engineer's claim (45/7 ×2, new suite SettingsValidationTests with
  2 tests, baseline was 43/6). Reviewer ran in parallel this gate —
  cross-check is orchestrator-collated post-hoc, not inline here.
- Warning triage: run 2 log carried 2 `warning:` lines, both
  `appintentsmetadataprocessor … Metadata extraction skipped. No
  AppIntents.framework dependency found.` — Xcode link-time tool noise, not a
  compiler diagnostic (xcresult warnings block empty); surfaces only on
  relink, which prior incremental warning-evidence runs never triggered.
  Added to flake registry. All other run-2 noise already registered
  (logging-persist/DetachedSignatures, XPC 4097, "Not vending elements");
  WarnOnce did not appear this time (registered as intermittent). The R3
  "'is' test is always true" warning in SmokeTests.swift again did not
  surface (file unchanged; incremental for that file) — still pre-existing.

**Git hygiene at gate:** staged code surface = exactly 3 files
(SettingsWindowController.swift new, SettingsValidationTests.swift new,
StatusItemController.swift delta), matching the announced 1E delta.

### 1D archive

**Test command:** `make test` — run TWICE (carried concurrency surface:
serialized TranscriptionServiceTests + URLProtocol global handler); both runs
identical.
**Counts (both runs):** 43 tests in 6 suites, 0 failures, 0 build warnings
(run 1 xcresult — the run that compiled the 1D delta incl. new
TextInserter.swift — issues block empty, testsCount 49 = 43 runner tests +
parameterized ×7 expansion; run 2 full log has zero `warning:` lines; run 2
was incremental/no-compile, so run 1's xcresult is the warning evidence).
- HotkeyStateMachineTests: 14 · WavEncoderTests: 6 · SettingsStoreTests: 6 ·
  KeychainStoreTests: 5 · MultipartBodyTests: 5 · TranscriptionServiceTests: 6
  · smoke appDelegateInitializes: 1 (freestanding — runner reports 6 suites)
- Matches reviewer's inline counts exactly (43 in 6 suites ×2; 1D adds no new
  tests — R12 is a new assertion inside existing requestMatchesSpec, which
  passed both runs).
- Known-noise present in run-2 log, all already in flake registry
  (logging-persist/DetachedSignatures, XPC 4097, WarnOnce, "Not vending
  elements"); no new noise. The R3 "'is' test is always true" warning in
  SmokeTests.swift again did not surface (file unchanged; incremental) —
  still tracked as pre-existing.

**Git hygiene at gate:** staged code surface = exactly 3 files
(TextInserter.swift new + DictationController.swift,
TranscriptionServiceTests.swift edits), matching the announced 1D delta.

### 1C archive

**Test command:** `make test` — run TWICE (new concurrency surface: serialized
TranscriptionServiceTests + URLProtocol global handler); both runs identical.
**Counts (both runs):** 43 tests in 6 suites, 0 failures, 0 build warnings
(run 1 xcresult issues block empty — 0 errors / 0 warnings / 0 analyzer
warnings; run 2 full log has zero `warning:` lines; xcresult testsCount 49 =
43 runner tests + parameterized ×7 expansion).
- HotkeyStateMachineTests: 14 · WavEncoderTests: 6 · SettingsStoreTests: 6 ·
  KeychainStoreTests: 5 · MultipartBodyTests: 5 · TranscriptionServiceTests: 6
  · smoke appDelegateInitializes: 1 (freestanding — runner reports 6 suites)
- Matches reviewer's inline counts (43 in 6 suites; new suites
  MultipartBodyTests 5, TranscriptionServiceTests 6 serialized).
- Note: the R3 "'is' test is always true" warning in SmokeTests.swift again
  did not surface (file unchanged; incremental) — still tracked as
  pre-existing.

**Real-endpoint oracle (tester-independent, no-app check):** synthesized a
fresh sentence ("The lotus blooms at midnight over silent water", `say` +
`afconvert` → 16 kHz / 1 ch / Int16 WAV, 2.85 s), curl multipart POST to
https://vllm.garison.com/v1/audio/transcriptions with model=whisper-large-v3
→ HTTP 200 in 1.08 s, body
`{"text":" The lotus blooms at midnight over silent water."}` — exact match.
Independent of engineer's "quick brown fox" probe.

**Git hygiene at gate:** staged = exactly 6 files (MultipartBody.swift,
TranscriptionService.swift, MultipartBodyTests.swift,
TranscriptionServiceTests.swift new + DictationController.swift,
SettingsStore.swift edits).

### 1B archive

**Counts:** 32 tests in 4 suites, 0 failures, 0 build warnings (xcresult
errorCount 0 / warningCount 0 / analyzerWarningCount 0).
- HotkeyStateMachineTests: 14 (13 functions + 1 parameterized ×7 cases) ·
  WavEncoderTests: 6 · SettingsStoreTests: 6 · KeychainStoreTests: 5 ·
  smoke appDelegateInitializes: 1 (freestanding — runner reports 4 suites)
- Matches reviewer's inline counts (32 in 4 suites, same per-suite split).
- Note: the R3 "'is' test is always true" warning in SmokeTests.swift did not
  surface this run (incremental build; file unchanged) — still tracked as
  pre-existing.

**WAV format oracle (no-app check):** `afconvert -f WAVE -d LEI16@16000 -c 1`
output inspected with afinfo + xxd — fmt chunk size 16, format 1 (PCM),
1 ch, 16000 Hz, byte-rate 32000, block-align 2, 16-bit: exactly the field
values WavEncoderTests assert. Real audio round-trip remains human verify 2.

**Info.plist (D11):** after `make generate`, generated
Sources/LotusScribe/Info.plist carries NSMicrophoneUsageDescription
("LotusScribe records audio while the dictation hotkey is held, …");
file stays gitignored.

### 1A archive
**Counts:** 26 tests in 3 suites, 0 failures, 0 build warnings (xcresult
errorCount 0 / warningCount 0).

**Graceful-degradation evidence (1A invariant):** hosted test run launches the
app binary unpermissioned; run log shows
`[Permissions] TCC at launch — listenEventAccess: false, accessibilityTrusted: false`
followed by `[EventTapMonitor] event tap started` — listen-only tap creation
succeeded without TCC grants (no failure path exercised), host did not crash,
all 26 tests passed.

## Phase 1 empirical record (2026-07-04, macOS 26 Tahoe, MacBook Pro 14/16 notch)

Final human-at-screen results, orchestrator-verified. Replaces the owed-items
lists previously carried at 1A/1B/1D/1E close.

**TCC matrix (records #1–#3):**
- BOTH Input Monitoring AND Accessibility toggles are required for tap
  delivery. No automatic prompt ever fired for either, despite
  `CGRequestListenEventAccess()` at launch (silently ignored) — the user had
  to enable both manually in System Settings.
- Ad-hoc re-signing invalidated the TCC grants on every rebuild (Q2
  confirmed); fixed by remove/re-add of the current binary in the TCC panes.
- Microphone prompt fired at FIRST recording start (not launch) — as
  predicted at 1B.

**Fn key:** NEVER delivered to the session event tap on macOS 26 — no
flagsChanged, no keyDown-63; lldb-verified at the tap callback. Shift
flagsChanged delivered fine, and `AppleFnUsageType=0` was set, so the tap
itself works — the OS withholds Fn specifically. Hold-Fn is unusable; the
chord fallback is in use.

**Dictation matrix** (chord ctrl+alt+cmd+9 — the original ctrl+alt+z
conflicted, suspending terminal apps via chord leakage), live endpoint
https://vllm.garison.com/v1/audio/transcriptions:

| target | result |
|--------|--------|
| TextEdit | PASS |
| Slack | PASS |
| browser textarea | PASS |
| Terminal | FAIL — transcript produced, synthetic Cmd-V not landed; secure-input diagnostics skipped by user; deferred to Phase 6 |
| password field | SKIPPED by user |

**Pipeline timing (live logs):** STT round-trip 0.92 s for a 1.2 s utterance;
1.7 s for a 10.5 s utterance. First-ever recording hit a 2.5 s engine cold
start → 0 PCM bytes captured → Whisper hallucinated " you" from empty audio
(defect queued).

**Settings:** Save/Cancel verified live; `defaults read` confirmed persisted
keys; empty LLM fields correctly absent (nil semantics).

**1B afinfo/QuickLook check:** superseded by end-to-end pipeline success —
the 16 kHz WAV is accepted by the real endpoint with correct transcripts.

## Flake registry (known-noise, carried from phase 0)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `appintentsmetadataprocessor … warning: Metadata extraction skipped. No AppIntents.framework dependency found.` (×2) on builds that relink | link-time tool noise, not a compiler diagnostic; xcresult warnings block stays empty (added at 1E) |
