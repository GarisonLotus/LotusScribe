# Architect Log — LotusScribe (Phase 11)

Locked decisions + open questions. Terse: id, date, decision, 1-line
rationale, sub-phase. Decision numbering continues from D107 (D106 = hotkey
default ⌘⌥D, commit 8db562b; D107 = cleanup-injection hardening, commits
267cfd3/a49945f — both doc'd only in commit messages, never in a phase log).
Phase 11 therefore uses D108+.

## Locked decisions

| ID | Date | Decision | Rationale | Sub-phase |
|----|------|----------|-----------|-----------|
| D108 | 2026-07-08 | Two new files: `AudioInputDevice.swift` (pure) + `CoreAudioDeviceEnumerator.swift` (edge) | D14 pure/edge separation; keep list-shaping unit-testable, Core Audio reads isolated | 11A |
| D109 | 2026-07-08 | Pure/edge split: pure = `resolvedID(forUID:in:)`, `AudioInputMenuModel`, ordering, label over `[AudioInputDevice]` values; edge = `AudioObjectGetPropertyData` reads producing those values | Tests hand-build device lists; no hardware in the pure layer | 11A |
| D110 | 2026-07-08 | `SettingsStore.inputDeviceUID: String?`, nil/empty = follow system, `normalizedString` idiom | Mirror `hotkeyChord`; UID stable across replug (handoff §3) | 11A |
| D111 | 2026-07-08 | `InputDeviceSetting.set(uid:)` writes store + posts `.lotusInputDeviceChanged`; notification name in HotkeyController.swift beside `.lotusHotkeyChanged` | Mirror `HotkeySetting`/`.lotusHotkeyChanged` live write-through (locked §5); both surfaces use it | 11A |
| D112 | 2026-07-08 | `AudioRecorder` owns a `CoreAudioDeviceEnumerator`, reads UID at `start()`, pins via `kAudioOutputUnitProperty_CurrentDevice` on `inputNode.auAudioUnit` BEFORE `engine.start()`; nil/absent → no-op fallback; does NOT observe the notification | Locked §2/§4; §1B invariant preserved (set before engine runs, no live swap) | 11B |
| D113 | 2026-07-08 | "Microphone ▸" submenu rebuilt on open via `NSMenuDelegate.menuNeedsUpdate`; renders the shared pure `AudioInputMenuModel`; menu need not observe the notification (rebuilds fresh) | Replug reflects live (handoff §3); checkmark logic tested once in 11A | 11C |
| D114 | 2026-07-08 | Settings mirror = self-owned `MicrophonePicker` view (mirror `HotkeyPicker`, NOT `SettingsDraft`), observes `.lotusInputDeviceChanged` to sync selection | Locked §5 live write-through; keeps both surfaces' checkmarks in sync | 11D |
| D115 | 2026-07-08 | Sequencing 11A → 11B → 11C → 11D (foundation-first) | Tested base before UI; 11B `defaults`-verifiable before any surface exists | all |
| D117 | 2026-07-08 | §11B ordering correction: pin device FIRST, THEN read `inputFormat` from the now-current node, THEN guard, THEN converter + `installTap` + `engine.start()`. Prior spec ordering (read format → guard → pin) fed a STALE pre-pin format into `installTap`; `setDeviceID` changes the node to the pinned device's native rate, so `installTap` with the stale format raises an uncaught AVAudioEngine NSException (crash) on any sample-rate mismatch (external/USB mics — the feature's main case). Guard now runs on the post-pin format (correct: pin-failure still degrades to default per D88). | Correctness: `installTap` format must match the node's current output format. §1B preserved — all steps still before `engine.start()`, no swap-while-running, no device read in `stop()`. Code-verified against live `AudioRecorder.start()`. | 11B |
| D116 | 2026-07-08 | Canonical System-Default label (round-trip R11A-2): known name → `"System Default (<name>)"`; nil/empty → bare `"System Default"`. Bare form is the sane empty case, accepted. "(follow)" was concept-phase phrasing, NOT the shipped label. 11C + 11D render the shared `AudioInputMenuModel.defaultLabel` verbatim (copy lock, not a redesign). | Locked product decision #3 (System Default shows its resolved name); spec §11A had only the populated form — closed so both surfaces emit identical copy. Code-verified against staged `AudioInputMenuModel.defaultLabel`. | 11A |

## Open questions

| ID | Question | Status | Raised |
|----|----------|--------|--------|
| Q11-1 | Decision-number base: git commits reference D106 (hotkey ⌘⌥D, 8db562b) and D107 (cleanup injection, 267cfd3/a49945f); docs stopped at D105 so the collision was invisible when authoring. | RESOLVED by orchestrator: Phase 11 renumbered D106–D113 → D108–D115; spec + log + handoff updated. | architect |
