# Tester baselines — LotusScribe (Phase 1)

> Last gate's counts + flake registry. Phase-0 archive:
> docs/phase-0-tester-baselines.md.

## Last gate

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

## HUMAN-AT-SCREEN remainder at 1E close (user owes before phase close)

1. **Settings window focus:** open Settings from the menu bar item → the
   Settings window comes frontmost and is key/focused.
2. **Settings persistence + effect:** edit sttModel in the Settings pane →
   quit → relaunch → value persists (verify:
   `defaults read com.garisonlotus.LotusScribe sttModel`) and the next
   dictation uses the edited model.

## HUMAN-AT-SCREEN remainder at 1D close (user owes before phase close)

1D verify is the PLAN.md phase gate — the whole end-to-end loop, user at
screen:

1. **Dictation matrix** against the live D13 endpoint
   (https://vllm.garison.com/v1/audio/transcriptions): hold hotkey, speak,
   release, transcript lands in the focused app — record pass/fail per
   target: TextEdit, Slack, browser textarea, Terminal.
2. **TCC record #3 — final prompt matrix:** on a fresh build, record every
   prompt/toggle needed for the full loop (Microphone, Accessibility for the
   Cmd-V synthetic keystroke), and explicitly note whether Input Monitoring
   ever fires → this file.
3. **Password-field negative observation:** focus a secure text field
   (e.g. Safari password box), dictate — record what happens (expected: no
   insertion or OS-blocked paste; note actual behavior).
4. **R16 (reviewer) — clipboard residue on paste failure:** if Cmd-V paste
   fails in any matrix cell but the pasteboard was already written, note the
   transcript-left-on-clipboard behavior in that matrix row (transcript
   remains user-visible on the clipboard).

Carried from 1C: spec 1C verify 2 (speak a known sentence, confirm
transcript in log) folds into matrix item 1 above. 1A/1B records below
remain owed.

## HUMAN-AT-SCREEN remainder for 1B close (user owes before phase close)

- Spec 1B verify step 2: hold Fn, speak ~3 s, release; `afinfo <temp>.wav`
  reports 16000 Hz, 1 ch, 16-bit LPCM; QuickLook playback intelligible.
- Spec 1B verify step 3 (TCC record #2): note when the Microphone prompt
  fires — expect on first `start()`, not at launch → record here.

## HUMAN-AT-SCREEN remainder for 1A close (user owes before phase close)

- Spec 1A verify step 2: set "Press fn key to: Do Nothing"; launch app;
  hold/release Fn → Console start/stop logs; repeat with
  `defaults write … hotkeyChord ctrl+alt+z`.
- Spec 1A verify step 3 (TCC record #1): on a fresh build, record which
  prompts/toggles (Accessibility vs Input Monitoring) were needed for the tap
  to deliver events → this file.

## Flake registry (known-noise, carried from phase 0)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `appintentsmetadataprocessor … warning: Metadata extraction skipped. No AppIntents.framework dependency found.` (×2) on builds that relink | link-time tool noise, not a compiler diagnostic; xcresult warnings block stays empty (added at 1E) |
