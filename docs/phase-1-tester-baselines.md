# Tester baselines — LotusScribe (Phase 1)

> Last gate's counts + flake registry. Phase-0 archive:
> docs/phase-0-tester-baselines.md.

## Last gate

**Sub-phase:** 1C
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

## HUMAN-AT-SCREEN remainder at 1C close (user owes before phase close)

Unchanged from 1B (mic TCC record #2 + speak/afinfo, below). 1C's own
in-app step — spec 1C verify 2, speak a known sentence and confirm the
transcript in the log — folds into 1D's phase-gate dictation matrix rather
than being owed separately.

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
