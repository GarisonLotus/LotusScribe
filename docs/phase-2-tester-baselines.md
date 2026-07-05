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

(none yet)

**Owed empirical items for Phase 2:**
- Q5: `.defaultTap` creation under existing grants (spec §2A verify 3) —
  record mode logged + any new prompt/pane.
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
