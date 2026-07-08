import CoreAudio
import Foundation

/// PURE, headless-testable device layer (Phase 11A, D108). Holds the value
/// type, all UID-matching / menu-shaping logic over `[AudioInputDevice]`
/// values, the enumeration protocol (injection seam), and the write path.
/// No Core Audio property reads live here — `import CoreAudio` is only for the
/// `AudioDeviceID` typedef. The concrete reads are in
/// `CoreAudioDeviceEnumerator` (EDGE). See docs/phase-11-spec.md §11A.

/// One input-capable audio device. Produced by the enumerator (EDGE), shaped
/// by the pure layer. Persistence keys off `uid` (stable across reboot/replug,
/// handoff §3); `id` is the ephemeral Core Audio handle used at capture time.
struct AudioInputDevice: Equatable {
    let uid: String
    let name: String
    let id: AudioDeviceID

    /// Resolve a persisted UID to the live device id, or nil to follow the
    /// system default (handoff §3): nil iff `uid` is nil/empty OR no enumerated
    /// device carries that UID; otherwise the matching device's id.
    static func resolvedID(forUID uid: String?, in devices: [AudioInputDevice])
        -> AudioDeviceID?
    {
        guard let uid, !uid.isEmpty else { return nil }
        return devices.first { $0.uid == uid }?.id
    }
}

/// Enumeration seam (D14): the pure layer and the UI depend on this, not on
/// Core Audio. The concrete `CoreAudioDeviceEnumerator` does the live reads;
/// tests hand-build `[AudioInputDevice]` values.
protocol AudioInputDeviceEnumerating {
    /// Input-capable devices (channel count > 0), unordered as the OS returns.
    func inputDevices() -> [AudioInputDevice]
    /// The device macOS currently picks as the default input, or nil.
    func defaultInputDevice() -> AudioInputDevice?
}

/// Shared pure menu model (D113/D114) driving BOTH the NSMenu (11C) and the
/// SwiftUI picker (11D). Built from a device snapshot + the resolved default
/// name + the pinned UID; exposes the "System Default" label, the ordered
/// entries with checkmarks, and whether the default row is checked. The UI
/// just renders — checkmark/ordering logic is tested once here.
struct AudioInputMenuModel {
    /// One rendered device row: the device plus whether it is the active pin.
    struct Entry: Equatable {
        let device: AudioInputDevice
        let isChecked: Bool
    }

    /// "System Default (<name>)" — the resolved name tells the user what
    /// following-system means right now (handoff §3). Falls back to a bare
    /// "System Default" when the default name is unknown.
    let defaultLabel: String
    /// Device rows ordered by name (case-insensitive), each with its checkmark.
    let entries: [Entry]
    /// True iff following system — no pin resolves (handoff §3).
    let defaultIsChecked: Bool

    init(devices: [AudioInputDevice], defaultDeviceName: String?, pinnedUID: String?) {
        let resolved = AudioInputDevice.resolvedID(forUID: pinnedUID, in: devices)
        defaultIsChecked = resolved == nil

        if let defaultDeviceName, !defaultDeviceName.isEmpty {
            defaultLabel = "System Default (\(defaultDeviceName))"
        } else {
            defaultLabel = "System Default"
        }

        entries = devices
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { Entry(device: $0, isChecked: $0.id == resolved) }
    }
}

/// The single write path for the input-device setting (locked §5), used by
/// both UI surfaces: persist the UID, then post the live-sync ping. Mirrors
/// `HotkeySetting.set` (HotkeyController.swift) — Defaults stay the source of
/// truth; the notification only refreshes the two UI checkmarks (the recorder
/// re-reads the UID at `start()`, handoff §3).
enum InputDeviceSetting {
    static func set(uid: String?, store: SettingsStore = SettingsStore()) {
        store.inputDeviceUID = uid
        NotificationCenter.default.post(name: .lotusInputDeviceChanged, object: nil)
    }
}
