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

**Last gate: 2C-waveform-fix** (2026-07-05, PARALLEL mode — reviewer +
architect ran concurrently; staged, NOT committed; base 5c7cd80, i.e.
on top of c83031f/5c7cd80).
- **Counts:** 80 tests in 12 suites, 0 failures — `make test` run TWICE,
  both runs identical (80/12 green each, TEST SUCCEEDED). Delta vs
  2C-fix baseline: +5 tests, suites unchanged — AudioLevelTests 5→10,
  matching engineer claim exactly (75 + 5).
- **Per-suite (run 2):** AudioLevelTests 10, DictationControllerTests 4,
  HotkeyStateMachineTests 22, KeychainStoreTests 5, MultipartBodyTests 5,
  PillPanelTests 5, PillViewModelTests 2, SettingsStoreTests 6,
  SettingsValidationTests 2, SettingsWindowControllerTests 5,
  TranscriptionServiceTests 6, WavEncoderTests 6 = 78 in suites + 2
  top-level tests (appDelegateInitializes, mainMenuRoutesPaste) = 80.
  Only AudioLevelTests changed vs the 2C-fix breakdown.
- **Staged surface:** `git diff --cached --stat` = 3 source
  (AudioLevel.swift `display(rms:)` dBFS mapping, PillView.swift
  render-time call, DictationController.swift +1 diagnostic log) + 1
  test file (AudioLevelTests.swift +5) — matches the claimed fix scope.
- **Cross-check:** parallel-mode — orchestrator collates. Tester counts
  match engineer's claimed 80/12 green ×2.
- **Warnings:** registry noise only (destination auto-pick,
  DetachedSignatures, task-name-port, NSCGS CA-commit/entangle at
  PillPanelTests). One new cosmetic line both runs, added to registry:
  `[CursorUI] ViewBridge to RemoteViewService Terminated ...
  NSViewBridgeErrorCanceled` (message self-describes as benign).
- **Flakes:** none — both runs identical, no pass-on-second-run tests.
- **HUMAN-GATE PROGRESS (orchestrator-supplied):**
  - **§2C verify 3 (waveform tracks voice): PASS** — user-confirmed
    2026-07-05 after this fix. Initial report was FAIL (bars frozen);
    root cause: linear RMS mapping defect, fixed by the dBFS
    `AudioLevel.display(rms:)` mapping in this diff.
  - **Still PENDING:** verify 1 (focus-steal), verify 2 (fullscreen),
    verify 4 (cold-start + observed `.warming` duration), verify 5
    (state flashes), verify 6 (no-9-leak dictation check).

**Prior gate: 2C-fix (D34)** (2026-07-05, PARALLEL mode — reviewer ran
concurrently; staged, NOT committed; code base afe0c98, HEAD 32b9d04
docs-only handoff commit).
- **Counts:** 75 tests in 12 suites, 0 failures — `make test` run TWICE,
  both runs identical (75/12 green each, TEST SUCCEEDED). Delta vs 2C
  baseline: +1 test, suites unchanged — DictationControllerTests 3→4
  (new D34 regression test `constructionDoesNotRaise`), matching
  engineer claim exactly.
- **Per-suite (run 2):** AudioLevelTests 5, DictationControllerTests 4,
  HotkeyStateMachineTests 22, KeychainStoreTests 5, MultipartBodyTests 5,
  PillPanelTests 5, PillViewModelTests 2, SettingsStoreTests 6,
  SettingsValidationTests 2, SettingsWindowControllerTests 5,
  TranscriptionServiceTests 6, WavEncoderTests 6 = 73 in suites + 2
  top-level tests (appDelegateInitializes, mainMenuRoutesPaste) = 75.
  Only DictationControllerTests changed vs the 2C breakdown.
- **Staged surface:** AudioRecorder.swift (D34: AudioRecorder-init
  `engine.prepare()` deleted — launch-blocking NSException),
  DictationControllerTests.swift (+1 regression test), 2 docs
  (phase-2-architect-log.md, phase-2-spec.md) — matches D34 scope.
- **Cross-check:** parallel-mode — orchestrator collates. Tester counts
  match engineer's claimed 75/12 green ×2.
- **Warnings:** registry noise as usual (destination auto-pick,
  DetachedSignatures, task-name-port, Accessibility-not-vending). One
  non-registry family observed during PillPanelTests: `[NSCGS] Warning:
  Invalid attempt to open a new transaction during CA commit` (×2) plus
  `[NSCGS] Ignoring request to entangle context after pre-commit` (×8)
  — cosmetic AppKit/CA logs at panel ordering; PillPanelTests surface
  is pre-existing 2B code untouched by the D34 diff; added to registry.
- **Flakes:** none — both runs identical, no pass-on-second-run tests.
- **Gate facts recorded (orchestrator-supplied):**
  - **Q5 CLOSED — empirical record:** tap mode is `defaultTap` at launch
    under existing Input Monitoring + Accessibility grants. Console line
    `event tap started (defaultTap)` observed 2026-07-05, verified by
    orchestrator + engineer.
  - **Q6 CLOSED — D29a rescinded as D34:** `engine.prepare()` at
    AudioRecorder init is fatal on an empty graph (NSException at
    launch), not merely ineffective. Discovered at the human gate by
    orchestrator lldb; the 2C prepare-at-init call is deleted, with
    `constructionDoesNotRaise` as the regression guard.
- **HUMAN-AT-SCREEN §2C verify 1–6: still PENDING**, minus the Q5
  Console item, which is now recorded above (folded-in 2A no-9-leak
  dictation check still owed; verify-4 `.warming` duration still owed).

**Prior gate: 2C** (2026-07-05, SEQUENTIAL mode — staged, NOT committed;
base commit 3a8a83e).
- **Counts:** 74 tests in 12 suites, 0 failures — `make test` run TWICE,
  both runs identical (74/12 green each, TEST SUCCEEDED). Count UNCHANGED
  vs 2B baseline (74/12), as expected: spec says no new tests in 2C
  (thin glue over TCC-bearing recorder; covered by human gate).
- **Per-suite (run 2):** AudioLevelTests 5, DictationControllerTests 3,
  HotkeyStateMachineTests 22, KeychainStoreTests 5, MultipartBodyTests 5,
  PillPanelTests 5, PillViewModelTests 2, SettingsStoreTests 6,
  SettingsValidationTests 2, SettingsWindowControllerTests 5,
  TranscriptionServiceTests 6, WavEncoderTests 6 = 72 in suites + 2
  top-level tests (appDelegateInitializes, mainMenuRoutesPaste) = 74.
  Identical to the 2B per-suite breakdown.
- **Cross-check:** matches reviewer's inlined 74/12 green and their
  "no new tests in the 2C diff" claim. No divergence.
- **Staged surface:** `git diff --cached --stat` = 2 source
  (AudioRecorder.swift, DictationController.swift), 2 docs
  (phase-2-architect-log.md, phase-2-reviewer-observations.md), 0 test
  files — consistent with "no new tests".
- **Warnings:** only registry noise observed (destination auto-pick,
  Accessibility-not-vending, DetachedSignatures, task-name-port). One
  non-registry line, informational not a warning: app's own
  `[Permissions] TCC at launch — listenEventAccess: true,
  accessibilityTrusted: true` log at hosted-app launch.
- **Flakes:** none — both runs identical, no pass-on-second-run tests.
- **HUMAN-AT-SCREEN §2C verify 1–6: PENDING (owed at this gate).**
  Includes verify-4 observed `.warming` duration (closes architect Q6)
  and the folded-in 2A items: no-9-leak dictation check + Q5 defaultTap
  "event tap started (mode)" Console record.

**Prior gate: 2B** (2026-07-05, SEQUENTIAL mode — staged, NOT committed;
base commit 51a040d).
- **Counts:** 74 tests in 12 suites, 0 failures — `make test` run TWICE,
  both runs identical (74/12 green each, TEST SUCCEEDED). Delta vs 2A
  baseline: +8 tests / +2 suites (66/10 at 51a040d → 74/12), matching
  engineer claim and reviewer's independent run exactly: +1 R29-regression
  in HotkeyStateMachineTests (21→22), +5 in new PillPanelTests, +2 in new
  PillViewModelTests.
- **Per-suite (run 2):** AudioLevelTests 5, DictationControllerTests 3,
  HotkeyStateMachineTests 22, KeychainStoreTests 5, MultipartBodyTests 5,
  PillPanelTests 5, PillViewModelTests 2, SettingsStoreTests 6,
  SettingsValidationTests 2, SettingsWindowControllerTests 5,
  TranscriptionServiceTests 6, WavEncoderTests 6 = 72 in suites + 2
  top-level tests (appDelegateInitializes, mainMenuRoutesPaste) = 74.
- **Cross-check:** matches reviewer's independent 74/12 TEST SUCCEEDED and
  their claimed delta breakdown. No divergence.
- **Staged surface:** `git diff --cached --stat` = 6 source (5 new Pill*
  + HotkeyStateMachine.swift R29 fix), 3 test files (HotkeyStateMachineTests
  + new PillPanelTests, PillViewModelTests), 2 docs — matches handoff §3.
- **Warnings:** only registry noise observed (destination auto-pick,
  Accessibility-not-vending, WarnOnce layoutSubtreeIfNeeded,
  DetachedSignatures, task-name-port). No compile step ran in the verified
  runs (incremental), so the pre-existing "'is' test is always true" 0A
  smoke-test compile warning did not surface; nothing new-in-this-diff.
- **Flakes:** none — no pass-on-second-run tests; both runs identical.

**Prior gate: 2A** (2026-07-04, PARALLEL mode — tester ran without reviewer
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
| 2026-07-05 | (known-noise) | `[NSCGS] Warning: Invalid attempt to open a new transaction during CA commit` + `[NSCGS] Ignoring request to entangle context after pre-commit` during PillPanelTests | cosmetic AppKit/CA panel-ordering logs; first recorded at 2C-fix gate on pre-existing 2B surface |
| 2026-07-05 | (known-noise) | `[CursorUI] ViewBridge to RemoteViewService Terminated: ... NSViewBridgeErrorCanceled` at hosted-app run | cosmetic; message self-describes as benign; first recorded at 2C-waveform-fix gate, both runs |
