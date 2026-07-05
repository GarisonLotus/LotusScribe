# Tester baselines — LotusScribe (Phase 2)

> Last gate's counts + flake registry. Archives: docs/phase-0-tester-baselines.md,
> docs/phase-1-tester-baselines.md (full phase-1 empirical record lives there).

## Baseline carried into Phase 2

**Commit:** b148cff (Phase 1 close, pushed).
**Counts:** 54 tests in 9 suites, 0 failures — 51/8 at cf5471c (last
phase-1 tester gate, run ×2) + 3 empty-audio-guard tests in the new
DictationControllerTests suite (reviewer-verified at b148cff, R28).
**Test command:** `make test` — run TWICE per gate; carried concurrency
surface: serialized TranscriptionServiceTests + URLProtocol global handler.

**Environment facts carried:** macOS 26 Tahoe; stable personal-team signing
(5RC66Q82V9) — TCC grants persist across rebuilds (Q1/Q2 closed); Input
Monitoring + Accessibility both granted and required for tap delivery; mic
prompt fires at first recording start, not launch.

## Phase 2 gates

**Last gate: 2A** (2026-07-04, PARALLEL mode — tester ran without reviewer
counts; orchestrator collates post-hoc).
- **Counts:** 66 tests in 10 suites, 0 failures — `make test` run TWICE,
  both runs identical (66/10 green each). Delta vs baseline: +12 tests /
  +1 suite (54/9 → 66/10), matching engineer claim: +7 swallow-matrix in
  HotkeyStateMachineTests (14→21), +5 in new AudioLevelTests.
- **Per-suite (run 2):** AudioLevelTests 5, DictationControllerTests 3,
  HotkeyStateMachineTests 21, KeychainStoreTests 5, MultipartBodyTests 5,
  SettingsStoreTests 6, SettingsValidationTests 2,
  SettingsWindowControllerTests 5, TranscriptionServiceTests 6,
  WavEncoderTests 6 = 64 in suites + 2 top-level tests
  (appDelegateInitializes, mainMenuRoutesPaste) = 66.
- **Staged surface:** `git diff --cached --stat` = 4 source
  (AudioLevel.swift new, AudioRecorder.swift, EventTapMonitor.swift,
  HotkeyStateMachine.swift) + 2 test files (AudioLevelTests.swift new,
  HotkeyStateMachineTests.swift) — matches engineer's list exactly.
- **Warnings:** all observed noise triaged — DetachedSignatures and
  Accessibility-not-vending match registry; two new cosmetic lines added
  to registry below; no non-registry warnings of substance.

**HUMAN-AT-SCREEN items owed at 2A close (not yet run):**
- No-9-leak dictation check: hold ctrl+alt+cmd+9, dictate into a focused
  app, confirm no "9" characters leak into the target text.
- Q5: `.defaultTap` creation under existing TCC grants — capture the
  Console "event tap started (mode)" log line to record which mode was
  actually used, plus any new prompt/pane.

**Owed empirical items for Phase 2 (later sub-phases):**
- Cold-start: observed `.warming` duration on first-ever dictation after
  relaunch (spec §2C verify 4).

## Flake registry (known-noise, carried from phase 1)

| date | test name | failure mode | notes |
|------|-----------|--------------|-------|
| 2026-07-04 | (known-noise) | linkd XPC errors (NSCocoaErrorDomain 4097) at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `[WarnOnce] layoutSubtreeIfNeeded` log at hosted-app launch | cosmetic, intermittent |
| 2026-07-04 | (known-noise) | `[logging-persist] .../DetachedSignatures - No such file or directory` during Keychain tests | Security framework noise |
| 2026-07-04 | (known-noise) | `Accessibility: Not vending elements` at hosted-app launch | cosmetic |
| 2026-07-04 | (known-noise) | `appintentsmetadataprocessor … Metadata extraction skipped. No AppIntents.framework dependency found.` (×2) on builds that relink | link-time tool noise; xcresult warnings block stays empty |
| 2026-07-04 | (known-noise) | `xcodebuild: WARNING: Using the first of multiple matching destinations` | tool notice, first seen at 2A gate; benign destination auto-pick |
| 2026-07-04 | (known-noise) | `[Common] Unable to obtain a task name port right for pid NNN: (os/kern) failure (0x5)` at hosted-app launch | cosmetic, intermittent (seen run 1 only at 2A gate) |
