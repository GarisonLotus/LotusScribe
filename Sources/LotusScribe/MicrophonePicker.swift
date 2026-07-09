import SwiftUI

/// The Phase 11 microphone picker (11D): a capsule menu of the live input
/// devices plus a "System Default (<name>)" row. Writes live through
/// `InputDeviceSetting.set` (persist + post `.lotusInputDeviceChanged`, D110) —
/// mirrors `HotkeyPicker`/`HotkeySetting.set`, NOT a `SettingsDraft` field. It
/// owns its own state, seeded from the persisted UID + a fresh device snapshot,
/// and re-reads on `.lotusInputDeviceChanged` so a status-bar-submenu change
/// (11C) syncs while Settings is open (and vice-versa). LotusTheme only.
struct MicrophonePicker: View {
    @State private var model: AudioInputMenuModel

    init() {
        _model = State(initialValue: MicrophonePicker.buildModel())
    }

    /// The capsule label — the active choice's name, or the resolved
    /// "System Default (<name>)" when following the system (handoff §3).
    private var currentLabel: String {
        if model.defaultIsChecked { return model.defaultLabel }
        return model.entries.first { $0.isChecked }?.device.name ?? model.defaultLabel
    }

    var body: some View {
        Menu {
            // nil UID → follow the system default (D116 label, checkmark iff
            // no pin resolves). Checkmark = the Menu's selection indication.
            Button { commit(uid: nil) } label: {
                if model.defaultIsChecked {
                    Label(model.defaultLabel, systemImage: "checkmark")
                } else {
                    Text(model.defaultLabel)
                }
            }
            Divider()
            ForEach(model.entries, id: \.device.uid) { entry in
                Button { commit(uid: entry.device.uid) } label: {
                    if entry.isChecked {
                        Label(entry.device.name, systemImage: "checkmark")
                    } else {
                        Text(entry.device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentLabel)
                    .font(.lotusMono(12))
                    .foregroundStyle(Color.lotusTextPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.lotusTextSecondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color.lotusControlFill, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        // Refresh the device list on open too, so a replug/unplug reflects
        // live (handoff §3) — the status-bar submenu rebuilds the same way.
        .onAppear { refresh() }
        // 11C ↔ 11D sync: a change on either surface reposts this; re-read the
        // pin + names so both checkmarks stay in step (mirrors HotkeyPicker's
        // `.lotusHotkeyChanged` resync).
        .onReceive(NotificationCenter.default.publisher(for: .lotusInputDeviceChanged)) { _ in
            refresh()
        }
    }

    /// Persist + live re-bind (D110): the recorder re-reads the UID at
    /// `start()`; this only moves the checkmark now.
    private func commit(uid: String?) {
        InputDeviceSetting.set(uid: uid)
        refresh()
    }

    private func refresh() {
        model = Self.buildModel()
    }

    /// Snapshot the live devices + the resolved default + the pinned UID into
    /// the shared pure menu model (checkmark/ordering logic tested in 11A).
    private static func buildModel() -> AudioInputMenuModel {
        let enumerator = CoreAudioDeviceEnumerator()
        return AudioInputMenuModel(
            devices: enumerator.inputDevices(),
            defaultDeviceName: enumerator.defaultInputDevice()?.name,
            pinnedUID: SettingsStore().inputDeviceUID)
    }
}
