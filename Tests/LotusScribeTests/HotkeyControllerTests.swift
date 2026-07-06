import Foundation
import Testing
@testable import LotusScribe

/// Phase 9C: HotkeyController construction smoke (R35) + the HotkeySetting
/// write-through helper (persists the choice AND posts the live re-bind ping).
/// Isolated `UserDefaults(suiteName:)` per instance — never `.standard`.
@MainActor
final class HotkeyControllerTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// R35: construction + start must not crash even when Input Monitoring is
    /// ungranted — the tap fails to create and logs ("functional when
    /// permissions denied" invariant). Same launch path as AppDelegate.
    @Test func constructsAndStartsWithoutCrashing() {
        let controller = HotkeyController(store: SettingsStore(defaults: defaults)) { _ in }
        controller.start()  // tap create fails gracefully without IM; no crash
    }

    /// D83/D84: the one write path persists `hotkeyChord` and posts the change
    /// notification so the live tap re-binds.
    @Test func setPersistsChoiceAndPostsChangeNotification() async {
        let store = SettingsStore(defaults: defaults)
        await confirmation("posts lotusHotkeyChanged") { posted in
            let observer = NotificationCenter.default.addObserver(
                forName: .lotusHotkeyChanged, object: nil, queue: nil
            ) { _ in posted() }
            HotkeySetting.set(.functionKey(6), store: store)
            NotificationCenter.default.removeObserver(observer)
        }
        #expect(store.hotkeyChord == "f6")
        #expect(defaults.string(forKey: "hotkeyChord") == "f6")
    }
}
