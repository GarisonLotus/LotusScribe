# Architect Log — LotusScribe (Phase 9)

Locked decisions (compact; git log carries provenance). Newest at bottom.

| ID | Date | Decision | Why | Sub-phase |
|----|------|----------|-----|-----------|
| D80 | 2026-07-06 | Default hotkey = F5 (`.combo(keyCode: 96, modifiers: [])`), hold-to-talk; AppDelegate fallback flips from `.fnHold` to F5 via new pure `HotkeyChord.resolved(from:)` | User decision — F5 is the mac dictation/mic key; D27 killed fn as a usable default | 9A/9B |
| D81 | 2026-07-06 | Bare function keys are a `.combo` with **empty modifiers** — no new `HotkeyChord` case; `handleCombo` untouched | Empty modifier set is a subset of every `flags`, so the existing combo path starts+swallows on keyDown and pair-balances keyUp (D30); flagsChanged never stops a bare key (no modifier to release) — all correct already | 9A |
| D82 | 2026-07-06 | `parse` gains `functionKeyCodes` (f1–f12, kVK_F1…F12); a **single** token is accepted only if it's a function key → bare hold; bare letters/digits still rejected (need ≥1 modifier). `fn`→`.fnHold` unchanged | Bare F-key holds must persist/parse; a bare letter would swallow that key globally — must stay rejected. D27 escape hatch: `fn` still parses from the custom field only | 9A |
| D83 | 2026-07-06 | Persist via new `SettingsStore.hotkeyChord` (normalizedString, empty→nil); hotkey is a **live write-through setting** (mirrors `appearanceCard`→`LotusAppearance.set`), NOT a `SettingsDraft` field | Locked decision #4 (immediate live re-bind) is incompatible with the buffered, probe-gated Save flow; appearance already sets the precedent | 9B/9D |
| D84 | 2026-07-06 | Live re-bind seam = new `HotkeyController` (owns the single `EventTapMonitor` + onAction; `rebind()` reads defaults→`resolved`→stop/new/start) observing `Notification.Name.lotusHotkeyChanged`; UI calls a `setHotkey` helper that persists then posts | AppDelegate owns the one monitor; a notification is the loosest coupling from the deep window controllers back to it. Defaults stay the single source of truth (D15). Dictation wiring untouched | 9C |
| D85 | 2026-07-06 | Picker = shared `HotkeyPicker` (F1–F12 menu + custom combo field w/ parse-validity hint), LotusTheme-only; Settings `hotkeyCard` + Onboarding `tryItStep` replace the static `fnKeycap`, copy → "hold your hotkey", HUD chip → selected label, add F5 macOS guidance | Locked decisions #2/#3/#5; reskin rules (no raw hex, LotusTheme components); reuse `endpointField` hint + `monoField` idioms | 9D |

## Open questions

- **F5 delivery on macOS 26 is UNVERIFIED (empirical, R7/D27).** Input Monitoring
  not yet granted on the test machine; D27 proved this platform silently drops fn.
  9D acceptance must confirm `hotkey action: startCapture` fires on an F5 hold once
  IM is granted. If F5 is dead like fn, escalate — default stays F5 (user decision)
  but the custom combo (`ctrl+alt+cmd+9`, proven) is the working fallback.
