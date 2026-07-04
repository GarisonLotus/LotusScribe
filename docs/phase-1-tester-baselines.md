# Tester baselines — LotusScribe (Phase 1)

> Last gate's counts + flake registry. Phase-0 archive:
> docs/phase-0-tester-baselines.md.

## Last gate

**Sub-phase:** 1A
**Test command:** `make test`
**Counts:** 26 tests in 3 suites, 0 failures, 0 build warnings (xcresult
errorCount 0 / warningCount 0).
- HotkeyStateMachineTests: 14 (13 functions + 1 parameterized ×7 cases) ·
  KeychainStoreTests: 5 · SettingsStoreTests: 6 · smoke appDelegateInitializes: 1
- Note: the R3 "'is' test is always true" warning in SmokeTests.swift did not
  surface this run (incremental build; file unchanged) — still tracked as
  pre-existing.

**Graceful-degradation evidence (1A invariant):** hosted test run launches the
app binary unpermissioned; run log shows
`[Permissions] TCC at launch — listenEventAccess: false, accessibilityTrusted: false`
followed by `[EventTapMonitor] event tap started` — listen-only tap creation
succeeded without TCC grants (no failure path exercised), host did not crash,
all 26 tests passed.

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
