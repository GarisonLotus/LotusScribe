# Tester Baselines — LotusScribe (Phase 11)

**Baseline (Phase 11 bootstrap):** 271 tests / 24 suites, 0 failures at Phase
10 close (2026-07-08). `make test`.

## 11A close

**284 tests / 25 suites, 0 failures.** `make test`, stable across 2 runs (run 1
5.362s, run 2 5.262s), no flakes. +13 over the 271/24 baseline, +1 suite → new
`AudioInputDeviceTests` suite (11 tests: 4 `resolvedID` UID-resolution cases, 6
`AudioInputMenuModel` label/ordering/checkmark cases, 1 `InputDeviceSetting`
write-path `confirmation` that persists the UID and posts
`lotusInputDeviceChanged` exactly once) + 2 added `SettingsStoreTests`. All 11
new `AudioInputDeviceTests` are live `#expect`/`#require`/`confirmation`
assertions (not skipped/commented) — spot-checked
`AudioInputDeviceTests.swift`. Matches reviewer's inlined 284/25. Baseline was
271/24; +13, +1 suite → 284/25 as expected.

## 11B close

**284 tests / 25 suites, 0 failures.** `make test`, stable across 2 runs (run 1
4.728s, run 2 ~11.5s wall incl. build; both 284/0/0), no flakes. 11B is a
capture-site edge sub-phase (AudioRecorder device pinning) that adds NO new unit
tests, so the count correctly stays at the 11A close baseline of 284/25 — no
DROP (no test broke) and no unexpected increase. Matches reviewer's inlined
284/25. Count unchanged is the expected, correct result for a no-new-tests edge
change.

## 11C close

**284 tests / 25 suites, 0 failures.** `make test`, stable across 2 runs (run 1
5.331s, run 2 5.503s; both 284/0/0), no flakes. 11C is an AppKit UI sub-phase
(status-bar "Microphone ▸" submenu) that adds NO new unit tests, so the count
correctly stays at the 11A close baseline of 284/25 — no DROP (no test broke)
and no unexpected increase. Matches parallel-mode expectation (orchestrator
collates reviewer count post-hoc). Count unchanged is the expected, correct
result for a no-new-tests UI sub-phase.

## 11D close

**284 tests / 25 suites, 0 failures.** `make test`, stable across 2 runs (run 1
6.303s, run 2 5.807s; both 284/0/0), no flakes. 11D is a SwiftUI Settings UI
sub-phase (`MicrophonePicker` + card) that adds NO new unit tests, so the count
correctly stays at the 11A close baseline of 284/25 — no DROP (no test broke)
and no unexpected increase. Matches parallel-mode expectation (orchestrator
collates reviewer count post-hoc). Count unchanged is the expected, correct
result for a no-new-tests UI sub-phase.

**Phase 11 close:** 11D is the last sub-phase. Final Phase 11 tally is 284/25,
0 failures — +13 over the 271/24 phase-open baseline, all +13 (and the +1 suite,
`AudioInputDeviceTests`) landing in 11A; 11B/11C/11D each added no tests.

## Flake registry

- (none carried forward)
