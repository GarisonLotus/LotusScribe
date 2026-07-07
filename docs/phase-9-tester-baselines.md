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

**9D close:** 244 tests / 23 suites, 0 failures (UI is thin — picker/parse
logic already covered by 9A/9C; verified HUMAN-AT-SCREEN). Empirical
F5-reaches-the-tap acceptance is OUTSTANDING — blocked on Input Monitoring
being granted on the test machine.

**9E close:** 249 tests / 24 suites, 0 failures (+5: HotkeyCollision
mapping incl. chord-based spelling variants per R9E-2/3).

**post-9E (D87/D88 default→⌘F5 + Input Monitoring ordering):** 249 tests /
24 suites, 0 failures. Count unchanged — 6 default-assertion expectations
retargeted from `combo(96, [])` to `combo(96, .maskCommand)` and
`from(persisted: nil/"")` from `.functionKey(5)` to `.custom("cmd+f5")`
across HotkeyStateMachineTests + SettingsStoreTests. No new tests (change is
a default value, existing coverage exercises the path). Hotkey verified
HUMAN-AT-SCREEN: hold ⌘F5 → pill appears.

## Flake registry

- (none recorded this phase)
