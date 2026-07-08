import CoreAudio
import Foundation
import Testing

@testable import LotusScribe

/// Phase 11A: the PURE device layer — UID resolution, the shared menu model
/// (label + ordering + checkmarks), and the `InputDeviceSetting` write path.
/// All hardware-free: tests hand-build `[AudioInputDevice]` values, and the
/// write-path test uses an isolated `UserDefaults(suiteName:)` like
/// `SettingsStoreTests`. See docs/phase-11-spec.md §11A.
final class AudioInputDeviceTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private let mic = AudioInputDevice(uid: "built-in", name: "MacBook Pro Microphone", id: 11)
    private let loopback = AudioInputDevice(uid: "loopback", name: "Loopback Audio", id: 22)

    private var devices: [AudioInputDevice] { [mic, loopback] }

    // MARK: - resolvedID

    @Test func resolvedIDIsNilForNilUID() {
        #expect(AudioInputDevice.resolvedID(forUID: nil, in: devices) == nil)
    }

    @Test func resolvedIDIsNilForEmptyUID() {
        #expect(AudioInputDevice.resolvedID(forUID: "", in: devices) == nil)
    }

    @Test func resolvedIDIsNilForAbsentUID() {
        #expect(AudioInputDevice.resolvedID(forUID: "gone", in: devices) == nil)
    }

    @Test func resolvedIDReturnsMatchingDeviceID() {
        #expect(AudioInputDevice.resolvedID(forUID: "loopback", in: devices) == 22)
    }

    // MARK: - AudioInputMenuModel

    @Test func defaultIsCheckedWhenPinnedUIDNil() {
        let model = AudioInputMenuModel(
            devices: devices, defaultDeviceName: "MacBook Pro Microphone", pinnedUID: nil)
        #expect(model.defaultIsChecked)
        #expect(model.entries.allSatisfy { !$0.isChecked })
    }

    @Test func defaultIsCheckedWhenPinnedUIDAbsent() {
        let model = AudioInputMenuModel(
            devices: devices, defaultDeviceName: "MacBook Pro Microphone", pinnedUID: "gone")
        #expect(model.defaultIsChecked)
        #expect(model.entries.allSatisfy { !$0.isChecked })
    }

    @Test func pinnedDeviceIsTheOnlyCheckedEntry() {
        let model = AudioInputMenuModel(
            devices: devices, defaultDeviceName: "MacBook Pro Microphone", pinnedUID: "loopback")
        #expect(model.defaultIsChecked == false)
        let checked = model.entries.filter { $0.isChecked }
        #expect(checked.count == 1)
        #expect(checked.first?.device == loopback)
    }

    @Test func labelShowsResolvedDefaultName() {
        let model = AudioInputMenuModel(
            devices: devices, defaultDeviceName: "MacBook Pro Microphone", pinnedUID: nil)
        #expect(model.defaultLabel == "System Default (MacBook Pro Microphone)")
    }

    @Test func labelDropsParensWhenDefaultNameUnknown() {
        let model = AudioInputMenuModel(devices: devices, defaultDeviceName: nil, pinnedUID: nil)
        #expect(model.defaultLabel == "System Default")
    }

    @Test func entriesAreOrderedByNameCaseInsensitively() {
        // Input order is mic, loopback; sorted output is Loopback then MacBook.
        let model = AudioInputMenuModel(
            devices: devices, defaultDeviceName: nil, pinnedUID: nil)
        #expect(model.entries.map { $0.device } == [loopback, mic])
    }

    // MARK: - InputDeviceSetting write path

    /// Locked §5: the one write path persists the UID AND posts the sync ping
    /// exactly once (mirrors HotkeySetting).
    @Test func setWritesUIDAndPostsOnce() async {
        let store = SettingsStore(defaults: defaults)
        await confirmation("posts lotusInputDeviceChanged once", expectedCount: 1) { posted in
            let observer = NotificationCenter.default.addObserver(
                forName: .lotusInputDeviceChanged, object: nil, queue: nil
            ) { _ in posted() }
            InputDeviceSetting.set(uid: "loopback", store: store)
            NotificationCenter.default.removeObserver(observer)
        }
        #expect(store.inputDeviceUID == "loopback")
        #expect(defaults.string(forKey: "inputDeviceUID") == "loopback")
    }
}
