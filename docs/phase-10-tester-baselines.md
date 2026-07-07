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

## Flake registry

- (none recorded this phase)
