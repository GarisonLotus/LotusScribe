# Tester Baselines — LotusScribe (Phase 9)

**Baseline (Phase 9 bootstrap):** 230 tests / 22 suites, 0 failures at
ab0b9f8 (2026-07-06). `make test`.

**9A close:** 239 tests / 22 suites, 0 failures (+9: function-key parse,
`resolved` default, `HotkeyOption` round-trips, bare-key D30 pair-balance).

**9B close:** 242 tests / 22 suites, 0 failures (+3: hotkeyChord round-trip,
empty→nil, absent→F5 resolve).

**9C close:** 244 tests / 23 suites, 0 failures (+2: HotkeyController
construct+start smoke, HotkeySetting persist+post). Log confirms launch
rebind → F5 (keycode 96).

## Flake registry

- (none recorded this phase)
