# Phase 9 Spec — User-Selectable Dictation Hotkey (LotusScribe)

Authoritative build plan. Read `docs/phase-9-team-handoff.md` first (context +
§4 load-bearing constraints). Edit surface for the implementer is source/tests;
this doc names the concrete symbols.

## Goal

Let the user choose the push-to-talk hotkey — **function keys F1–F12** (bare
holds) or a **custom modifier-combo** (existing `ctrl+alt+cmd+9` format) — from
onboarding step 3 AND Settings, taking effect **immediately (live re-bind)** with
no relaunch. Default = **F5** (kVK_F5 = 96), hold-to-talk.

## Locked decisions (see phase-9-architect-log D80–D85)

1. Default hotkey = F5 (`.combo(keyCode: 96, modifiers: [])`).
2. Bare F-keys = a **combo with empty modifiers** — no new `HotkeyChord` case.
   `handleCombo` already handles `modifiers: []` correctly (empty set is a
   subset of every `flags`, so keyDown always starts+swallows; keyUp swallow is
   pair-balanced; flagsChanged never stops — a bare key has no modifier to
   release). D30 is preserved with **zero** changes to `handleCombo`.
3. Hotkey is a **live write-through setting** (like `appearanceCard` →
   `LotusAppearance.set`), NOT a buffered `SettingsDraft` field — so it dodges
   the probe-gated Save flow and applies instantly.
4. `.fnHold` stays reachable only by typing `fn` in the custom field (D27 —
   older-macOS escape hatch, never a picker choice).

## Resolved design

### Chord model (`HotkeyStateMachine.swift`)
- Add `functionKeyCodes: [String: Int64]` = f1:122, f2:120, f3:99, f4:118,
  **f5:96**, f6:97, f7:98, f8:100, f9:101, f10:109, f11:103, f12:111
  (HIToolbox kVK_F1…F12; positional — R7 caveat applies as it does to ANSI).
- `HotkeyChord.parse`: key-token lookup consults `keyCodes` **and**
  `functionKeyCodes`. A **single** token is accepted only when it resolves via
  `functionKeyCodes` → `.combo(keyCode:, modifiers: [])`. Everything else keeps
  the ≥1-modifier rule (bare `a`/`5`/`z` still rejected — critical: a bare
  letter would swallow that key globally). `fn` → `.fnHold` unchanged.
- Add pure `static func HotkeyChord.resolved(from: String?) -> HotkeyChord` =
  `string.flatMap(parse) ?? .combo(keyCode: 96, modifiers: [])` (the F5
  default). Headless-testable (D14).

### Presentation model (new `HotkeyOption` in `HotkeyStateMachine.swift`)
```
enum HotkeyOption: Equatable {
    case functionKey(Int)   // 1...12
    case custom(String)     // raw combo string, e.g. "ctrl+alt+cmd+9"
    var persisted: String        // "f5" | the custom string
    var chord: HotkeyChord?      // via HotkeyChord.parse(persisted)
    static func from(persisted: String?) -> HotkeyOption  // "f<n>" → .functionKey, else .custom
}
```
Pure, unit-tested — maps selection ⇄ persisted `hotkeyChord` string ⇄ chord.

### Persistence (`SettingsStore.swift`)
- Add `var hotkeyChord: String?` (the `normalizedString(forKey:)` idiom; empty→nil,
  D25/R39). Replaces AppDelegate's raw `UserDefaults.standard.string(forKey:)`.

### Live re-bind seam (new `HotkeyController.swift`)
AppDelegate owns exactly one monitor today. Extract that ownership into a small
`HotkeyController` (TCC-bearing lifecycle owner, mirrors EventTapMonitor's role
— NOT unit-tested for tap creation, gets an R35 construction smoke test):
- Holds the `onAction` closure (dictation wiring — untouched) and the current
  `EventTapMonitor`.
- `func rebind()`: read `SettingsStore().hotkeyChord` → `HotkeyChord.resolved` →
  `stop()` old monitor, build a fresh `EventTapMonitor(chord:onAction:)`,
  `start()`. (Machine is immutable, so rebind = new monitor.)
- Observes `Notification.Name.lotusHotkeyChanged`; `start()` at launch.
- Free helper `HotkeyController.setHotkey(_ option: HotkeyOption)` (or on
  SettingsStore): persists `option.persisted`, then posts the notification.
  Both UI surfaces call ONLY this — defaults stay the single source of truth
  (D15 read idiom); the notification is a bare "changed" ping.
- `AppDelegate.applicationDidFinishLaunching`: replace the inline
  `hotkeyMonitor` block with `hotkeyController = HotkeyController(onAction:)`
  then `.start()`. Dictation composition unchanged.

### UI (shared `HotkeyPicker`, used by both surfaces)
New SwiftUI subview `HotkeyPicker` (LotusTheme only — no raw hex/ad-hoc fonts):
- A `Menu` (borderlessButton, `.lotusAccentText`) listing F1–F12 + "Custom…".
- When custom: reveal a `monoField`-style combo field with a parse-validity
  hint (reuse the `endpointField` orange-hint idiom; invalid → keep old chord).
- Bound to a `HotkeyOption`; on change calls the write-through helper.
- **Settings** (`SettingsForm.swift`): add `hotkeyCard` (a `LotusCard` beside
  `appearanceCard`, same live-write-through pattern — NOT a draft field).
- **Onboarding** (`OnboardingView.tryItStep`): replace the static `fnKeycap`
  with `HotkeyPicker`; change copy "Hold the **fn**" → "Hold your hotkey";
  update `HUDPreview`'s hardcoded "fn" chip to the selected key label; keep the
  older-macOS fn footnote AND add F5 guidance (disable the system Dictation
  shortcut; use standard function keys so F5/keycode 96 reaches the session tap).

## Sub-phases (each independently committable: modules + tests + docs)

**9A — Chord model + option type.** `functionKeyCodes`, `parse` single-fn-token
relaxation, `HotkeyChord.resolved`, `HotkeyOption`.
- Success: `HotkeyStateMachineTests` — `parse("f5") == .combo(96, [])`;
  `parse("a")`/`parse("5")`/`parse("")` == nil; `parse("shift+f5")` combos;
  `parse("fn") == .fnHold`; `resolved(nil) == .combo(96, [])`; `HotkeyOption`
  round-trips both variants; a D30 pair-balance sequence for a bare-key chord
  (keyDown 96 → startCapture+swallow, autorepeat → swallow, keyUp 96 →
  stopCapture+swallow, and flagsChanged never stops it). All green; no
  `handleCombo` edits.

**9B — Persistence + F5 default.** `SettingsStore.hotkeyChord`; AppDelegate
default via `HotkeyChord.resolved`.
- Success: `SettingsStoreTests` round-trip (incl. empty→nil); a test that an
  absent key resolves to F5 and `fn`/custom strings still parse.

**9C — Live re-bind seam.** `HotkeyController` + `Notification.Name.lotusHotkeyChanged`
+ `setHotkey` helper; AppDelegate rewire.
- Success: R35 construction-smoke (new `HotkeyControllerTests`);
  `setHotkey` writes the store and posts the notification (assert both);
  `AppDelegateTests`/`SmokeTests` still green (real post-launch composition).

**9D — UI: HotkeyPicker + Settings card + Onboarding step 3.** Shared picker,
`hotkeyCard`, `tryItStep` reskin + copy/guidance.
- Success: builds; picker maps selection↔option (logic already covered 9A);
  thin UI verified HUMAN-AT-SCREEN — pick F5 and hold → HUD appears with no
  relaunch; pick a custom combo → works; onboarding shows the picker + F5
  guidance. **Empirical F5 acceptance (below) runs here.**

## Load-bearing invariants to preserve

- **D30** swallow pair-balance: bare-fn support rides `handleCombo`'s existing
  `modifiers: []` path — do NOT touch `handleCombo`; the 9A test proves balance.
- **D27**: `.fnHold` stays in code (older macOS) but is never a picker option;
  reachable only via the custom `fn` string.
- **R7**: F-key + ANSI keycodes are positional; the picker maps label→keycode —
  document the caveat in the map's doc comment.
- **D14/D26**: keep decision logic pure/headless (`HotkeyOption`,
  `HotkeyChord.resolved`); the hotkey is a live setting, so it does NOT enter
  `SettingsDraft`/the probe-gated Save.

## Empirical risk (must verify in 9D)

F5 delivery to a `.cgSessionEventTap` on **macOS 26 is UNVERIFIED** — Input
Monitoring is not yet granted on the test machine, and D27 proves this platform
lies about key delivery (fn is silently dead). The custom-combo field
(`ctrl+alt+cmd+9`, proven working) is the hedge. **Acceptance step:** once IM is
granted, hold F5 and confirm the log emits `hotkey action: startCapture`
(`AppDelegate`/`EventTapMonitor` log lines). If F5 is dead like fn, the default
stays F5 per the user decision but this must be surfaced to the orchestrator/user
— the custom combo remains the working fallback.
