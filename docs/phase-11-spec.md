# Phase 11 Spec — Microphone selection

Shape-only. Grounds every symbol against the live tree. User request (handoff
§2): pick which audio input device dictation records from, instead of always
the system default. Honors the 6 LOCKED product decisions (handoff §3) verbatim
— they are user-decided, not open. Four independently-committable sub-phases,
4-way gate each. Do NOT change transcription/cleanup/networking semantics — this
is a capture-source selector + two UI surfaces + one settings key. Reskin rules:
LotusTheme only, no raw hex, ≥11pt, honor Reduce Motion.

## Locked shape decisions (see architect log D108–D115)

- **Two files** for the device layer (D14 pure/edge split, D108/D109):
  - `AudioInputDevice.swift` — **PURE, headless-testable**: the value type, all
    list-shaping / UID-matching / menu-model logic over `[AudioInputDevice]`
    values, the `AudioInputDeviceEnumerating` protocol (injection seam), and the
    `InputDeviceSetting` write path.
  - `CoreAudioDeviceEnumerator.swift` — **EDGE, human-verified**: the concrete
    `AudioInputDeviceEnumerating` doing the Core Audio property reads (TCC/
    hardware). No pure logic here — it produces `[AudioInputDevice]` values the
    pure layer shapes.
- **Persistence by UID** (handoff §3): `SettingsStore.inputDeviceUID: String?`,
  nil/empty = follow system. Mirrors the `hotkeyChord` `normalizedString` idiom.
- **Live write-through** (locked §5): `InputDeviceSetting.set(uid:)` writes the
  store then posts `.lotusInputDeviceChanged` — mirrors `HotkeySetting.set` /
  `.lotusHotkeyChanged`. NOT `SettingsDraft`. Both surfaces call it.
- **Recorder reads the UID at `start()`** (locked §4 + orchestrator call): it
  does NOT observe the notification; the notification only refreshes the two UI
  checkmarks. Pin applies at the NEXT dictation; §1B invariant preserved.
- **Silent fallback** (locked §2): pinned UID absent at `start()` → no pin, no
  warning, no error pill; engine uses the system default.
- **One shared pure menu model** (D113/D114): `AudioInputMenuModel` built from
  `(devices, defaultDeviceName, pinnedUID)` drives BOTH the NSMenu (11C) and the
  SwiftUI picker (11D). Checkmark logic is tested once in 11A; the UI just renders.

---

## 11A — Device layer + store key + write path (headless foundation) — ship first

Everything testable lands here so the UI sub-phases build on a tested base.

**Deliverable**
- `AudioInputDevice.swift` (PURE):
  - `struct AudioInputDevice: Equatable { let uid: String; let name: String;
    let id: AudioDeviceID }` (`import CoreAudio` for the `AudioDeviceID` typedef
    only — no property reads here).
  - `static func resolvedID(forUID uid: String?, in devices: [AudioInputDevice])
    -> AudioDeviceID?` — nil if uid nil/empty OR not present; else the match's id.
  - `AudioInputMenuModel` (pure): built from `(devices:, defaultDeviceName:,
    pinnedUID:)`. Exposes the System-Default label (canonical rule D116:
    `defaultDeviceName` known → `"System Default (<name>)"`; nil/empty → bare
    `"System Default"`. "(follow)" in early concept phrasing is NOT the shipped
    label — locked product decision #3: System Default shows its resolved name),
    the ordered device entries each with `isChecked`, and `defaultIsChecked`
    (true iff `resolvedID(forUID: pinnedUID, in: devices) == nil`). Filtering to
    input-capable devices happens in the enumerator (channel count is a Core
    Audio read); the pure model assumes the list is already input-only and just
    orders (by name) + marks checkmarks.
  - `protocol AudioInputDeviceEnumerating { func inputDevices() ->
    [AudioInputDevice]; func defaultInputDevice() -> AudioInputDevice? }`.
  - `enum InputDeviceSetting { static func set(uid: String?, store:
    SettingsStore = SettingsStore()) { store.inputDeviceUID = uid;
    NotificationCenter.default.post(name: .lotusInputDeviceChanged, object: nil) } }`
    — mirrors `HotkeySetting` (HotkeyController.swift).
- `SettingsStore.swift`: add `var inputDeviceUID: String?` via `normalizedString`
  /`defaults.set`, with a doc-comment mirroring `hotkeyChord`'s (nil/empty =
  follow system; live write-through; posts `.lotusInputDeviceChanged`).
- `HotkeyController.swift`: add `.lotusInputDeviceChanged` to the existing
  `extension Notification.Name` (beside `.lotusHotkeyChanged`), same reverse-DNS
  idiom (`"com.garisonlotus.LotusScribe.inputDeviceChanged"`).
- `CoreAudioDeviceEnumerator.swift` (EDGE): `final class` conforming to
  `AudioInputDeviceEnumerating`. `inputDevices()` enumerates
  `kAudioHardwarePropertyDevices` on `kAudioObjectSystemObject` via
  `AudioObjectGetPropertyDataSize`/`AudioObjectGetPropertyData`, then per device
  reads `kAudioDevicePropertyDeviceUID`, the device name
  (`kAudioObjectPropertyName` — *engineer to confirm at compile vs
  `kAudioDevicePropertyDeviceNameCFString`*), and input channel count via
  `kAudioDevicePropertyStreamConfiguration` scoped `kAudioObjectPropertyScopeInput`
  (keep only channel count > 0 — includes virtual mics, excludes output-only,
  handoff §3). `defaultInputDevice()` reads
  `kAudioHardwarePropertyDefaultInputDevice` then maps its id → the matching
  enumerated device. Degrades to `[]`/nil on any Core Audio error (must not throw
  before mic TCC is granted — constraint D88).

**Pure/headless (D14):** `resolvedID(forUID:in:)`, `AudioInputMenuModel`
(label + checkmarks + ordering), `InputDeviceSetting.set`, `inputDeviceUID`
round-trip. **Edge (human):** the enumerator's live reads.
**Files:** `AudioInputDevice.swift`, `CoreAudioDeviceEnumerator.swift`,
`SettingsStore.swift`, `HotkeyController.swift`, `AudioInputDeviceTests.swift`,
`SettingsStoreTests.swift`.
**Verify:** unit — `resolvedID(nil/"" ) == nil`; absent uid → nil; present uid →
its id; menu model: `defaultIsChecked` true when pinnedUID nil/absent, the pinned
device is the only checked entry when present, label reads "System Default
(<name>)" when the default name is known and bare "System Default" when nil/empty
(D116; 11C + 11D render this shared `defaultLabel` verbatim), entries ordered by
name; `InputDeviceSetting.set` writes the UID and
posts once (in-memory `UserDefaults`, like `SettingsStoreTests`); empty/absent
`inputDeviceUID` reads nil. Build+test green. HUMAN-AT-SCREEN: none (headless).

---

## 11B — AudioRecorder device pinning (capture site)

Makes the pin real; verifiable via `defaults write` before any UI exists.

**Deliverable (`AudioRecorder.swift`)**
- Add `private let devices: AudioInputDeviceEnumerating = CoreAudioDeviceEnumerator()`
  (injectable for future tests; default is the edge).
- In `start()`, BEFORE `engine.start()` and after the input-format guard: read
  `SettingsStore().inputDeviceUID`; if non-nil AND
  `AudioInputDevice.resolvedID(forUID:in: devices.inputDevices())` returns an id,
  set it on `engine.inputNode.auAudioUnit` via `kAudioOutputUnitProperty_CurrentDevice`
  (*engine to confirm the exact call at compile: AUAudioUnit `deviceID` setter vs
  `AudioUnitSetProperty` on `inputNode.audioUnit` — name the property, confirm the
  signature*). nil/unresolved → do nothing (silent fallback, locked §2). Log the
  resolved-vs-fallback choice (privacy `.public`), matching the existing
  `recording started` log idiom.
- §1B invariant preserved: the device is set as part of `start()`, before the
  engine runs; no swap while running, no new device read in `stop()`.

**Pure/headless (D14):** none new — the pin DECISION is 11A's `resolvedID`
(already tested); the pin ITSELF is the Core Audio edge. Existing 271-test suite
must stay green.
**Files:** `AudioRecorder.swift`.
**Verify:** unit — full suite green (recorder pin is edge, not unit-run). HUMAN-
AT-SCREEN: `defaults write com.garisonlotus.LotusScribe inputDeviceUID <a real
UID>` then dictate → capture comes from that device; set a bogus/unplugged UID →
dictation still works from the system default (silent fallback); clear the key →
follows system. Pin persists across app relaunch (it's read fresh each `start()`).

---

## 11C — "Microphone ▸" status-bar submenu (first UI surface)

**Deliverable (`StatusItemController.swift`)**
- In `init()`, insert a `NSMenuItem(title: "Microphone", …)` with a `submenu`
  (an `NSMenu`) above "Settings…"; keep the existing items/order otherwise.
- Set the submenu's `delegate = self` and implement `menuNeedsUpdate(_:)`
  (`NSMenuDelegate`) to REBUILD it on open (handoff §3 — replug reflects live):
  `removeAllItems()`, enumerate via a `CoreAudioDeviceEnumerator`, build
  `AudioInputMenuModel(devices:defaultDeviceName:pinnedUID: SettingsStore()
  .inputDeviceUID)`, then add: a "System Default (<name>)" item (checkmark iff
  `defaultIsChecked`), a divider, one item per device (checkmark iff its entry
  `isChecked`). Each item's action writes via `InputDeviceSetting.set` — System
  Default → `set(uid: nil)`; a device → `set(uid: device.uid)`. Use
  `NSMenuItem.representedObject`/`tag` to carry the UID to the `@objc` handler.
- Conform `StatusItemController` to `NSMenuDelegate`; it is already `NSObject`
  `@MainActor`. The submenu need not observe `.lotusInputDeviceChanged` — it
  rebuilds fresh on every open.

**Pure/headless (D14):** none new (menu model tested in 11A; NSMenu is AppKit UI).
**Files:** `StatusItemController.swift`.
**Verify:** unit — suite green. HUMAN-AT-SCREEN: open the menu → "Microphone ▸"
lists System Default (with the resolved device name) + all input devices;
checkmark sits on the active choice; clicking a device pins it (checkmark moves,
next dictation records from it); reopening after replug shows the new list.

---

## 11D — Settings mirror picker

**Deliverable**
- New `MicrophonePicker.swift` — a self-owned SwiftUI view mirroring
  `HotkeyPicker` (owns its own `@State`, seeds from `SettingsStore()
  .inputDeviceUID` + a live `CoreAudioDeviceEnumerator` snapshot; LotusTheme
  capsule `Menu` styled like the hotkey `Menu`). Menu contents built from the
  shared `AudioInputMenuModel`: "System Default (<name>)" + a divider + one item
  per device; selecting commits via `InputDeviceSetting.set(uid:)` (live write-
  through). `.onReceive(publisher(for: .lotusInputDeviceChanged))` refreshes the
  selection/label so a menu-driven change syncs while Settings is open. Tokens:
  `.lotusMono(12)`, `Color.lotusTextPrimary/Secondary`, `Color.lotusControlFill`,
  `Color.lotusSurfaceBorder` (mirror HotkeyPicker; ≥11pt, no raw hex).
- `SettingsForm.swift`: add a `microphoneCard` (mirror `hotkeyCard`: `LotusCard`
  + `cardHeader("Microphone")` + a `cardRow(divider: false)` hosting
  `MicrophonePicker()` and a `.lotusCaption`/`.lotusTextTertiary` note, e.g.
  "Records from this device. System Default follows macOS."). Place it beside
  `hotkeyCard` in the `body` stack. No `SettingsDraft` field — this is live
  write-through (locked §5), independent of Save/Cancel.

**Pure/headless (D14):** none new (menu model tested in 11A; the picker is UI).
**Files:** `MicrophonePicker.swift`, `SettingsForm.swift`.
**Verify:** unit — suite green. HUMAN-AT-SCREEN: Settings shows the Microphone
card with the same list; picking a device pins it; changing the device from the
status-bar submenu while Settings is open updates the Settings picker's selection
(and vice-versa) via `.lotusInputDeviceChanged`; System Default row shows the
live resolved name.

---

## Sub-phase summary

| ID | Deliverable | Headless (D14) | Files |
|----|-------------|----------------|-------|
| 11A | Device layer (pure+edge) + `inputDeviceUID` + write path/notification | `resolvedID`, `AudioInputMenuModel`, `InputDeviceSetting`, store key | AudioInputDevice, CoreAudioDeviceEnumerator, SettingsStore, HotkeyController, +2 test files |
| 11B | `AudioRecorder` pins the input before `engine.start()`; silent fallback | none new (reuses 11A `resolvedID`) | AudioRecorder |
| 11C | "Microphone ▸" submenu, rebuilt on open, checkmark + write | none new (renders 11A model) | StatusItemController |
| 11D | Settings mirror picker, live write-through, notification-synced | none new (renders 11A model) | MicrophonePicker, SettingsForm |

**Sequencing:** 11A → 11B → 11C → 11D. 11A first (tested base); 11B makes the pin
real and `defaults`-verifiable before any UI; 11C/11D are thin renderers of 11A's
pure menu model.

**Engineer-to-confirm-at-compile (Core Audio, un-runnable locally):** (1) the
device-name property (`kAudioObjectPropertyName` vs
`kAudioDevicePropertyDeviceNameCFString`); (2) the pin call on
`inputNode.auAudioUnit` (AUAudioUnit `deviceID` setter vs `AudioUnitSetProperty`
with `kAudioOutputUnitProperty_CurrentDevice`). All other constants
(`kAudioHardwarePropertyDevices`, `kAudioDevicePropertyDeviceUID`,
`kAudioHardwarePropertyDefaultInputDevice`, `kAudioDevicePropertyStreamConfiguration`,
`kAudioObjectSystemObject`, `kAudioObjectPropertyScopeInput`,
`AudioObjectGetPropertyData`/`Size`) are named as Apple spells them.
