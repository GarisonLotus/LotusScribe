# Tester Baselines — LotusScribe (Phase 10)

**Baseline (Phase 10 bootstrap):** 249 tests / 24 suites, 0 failures at
`03f4ebe` (2026-07-06). `make test`.

## 10A close

**254 tests / 24 suites, 0 failures.** `make test`, stable across 2 runs, no
flakes. +5 label tests (D89 `spelledLabel`): "Command + F5", bare "F5",
"Control + Option + Command + 9", "fn", and canonical-order
"Option + Shift + Command + Z". All are live `#expect` assertions (not
skipped/commented). Baseline was 249/24; +5 → 254/24 as expected.

## 10B close

**254 tests / 24 suites, 0 failures** (unchanged — 10B is pure UI, no new
tests). Orchestrator re-ran `make test` (no tester dispatch — no automated
signal beyond regression). Build green. Visual flow (4 dots, nav, kickers)
verified HUMAN-AT-SCREEN.

## 10C close

**258 tests / 24 suites, 0 failures** (+4 over 254: 3 suggested-model
assertions + `applyRecommendedFillsAllFourDraftFields` prefill test).
Reviewer + architect + orchestrator all independently re-ran green. Build
green. HUMAN persistence check (Use recommended fills 4 fields; Continue →
Settings shows saved values) folded into the next onboarding relaunch
(10E rebuild).

## 10E1 close

**263 tests / 24 suites, 0 failures** (+5 over 258: 5 predicate/seam tests —
`shouldShowSetupHint` cases for empty/failed/inserted/tooShort/nil plus the
`onOutcome == nil` default-seam assertion). Run TWICE, both green, no flakes.
Predicate cases confirmed live `#expect` assertions (not skipped/commented).

## 10E2 close

**263 tests / 24 suites, 0 failures** (no new tests — UI + human-verified).
Reviewer APPROVE (code). SELF-INSERTION SPIKE PASSED human-at-screen: with
STT pointed at reachable vLLM, holding ⌘F5 on the Try-it step landed the real
transcript ("Hello, hello.") in the focused box — authentic insertion into
the app's own window confirmed. Also confirms 10C persistence (endpoints
entered on Setup step reached the pipeline) and the ⌘F5 hotkey end-to-end.

## 10F close

**266 tests / 24 suites, 0 failures** (+3 over 263, 1 retargeted). Run TWICE,
both green (5.0s / 5.0s), no flakes. New: `usesMicKeyTrueForBothF5Chords`,
`usesMicKeyFalseForNonF5ChordsAndFnHold` (D103), plus the ⌘F5-clean assertion.
Retargeted: bare-F5 collision test now asserts message CONTAINS "Command"
(old "Turn both off" wording GONE — grep 0 hits across Sources/ + Tests/, not
duplicated). All confirmed live `#expect` (not skipped/commented).

## 10G close

**266 tests / 24 suites, 0 failures** (net 0 — retargets existing assertions,
adds none). Run TWICE, both green (4.9s / 4.9s), no flakes. Default hotkey
retargeted ⌘F5 → ⌃⌥D: nil/empty `hotkeyChord` now resolves to
`.combo(keyCode: 2, [.maskControl, .maskAlternate])` and
`HotkeyOption.from(persisted:)` nil/"" → `.custom("ctrl+option+d")`. Confirmed
live `#expect`. No stale "default resolves to ⌘F5" assertion remains — grep
`cmd+f5`/`maskCommand`/`f5` hits are all explicit non-default parse/round-trip/
collision/label cases. `parse("f5")` → `.combo(96, [])` and functionKey(5)
round-trips present + unchanged.

## Flake registry

- (none recorded this phase)
