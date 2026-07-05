import AppKit
import Foundation
import Testing
@testable import LotusScribe

/// Hosted tests: window materialization for the settings pane. Guards the
/// live defect where `SettingsWindowController()` resolved to the inherited
/// `NSWindowController.init()` (window: nil) and `show()` silently no-oped.
@MainActor
final class SettingsWindowControllerTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func showMaterializesVisibleWindow() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let controller = SettingsWindowController(store: SettingsStore(defaults: defaults))
        controller.show()
        defer { controller.window?.close() }

        let window = try #require(controller.window)
        #expect(window.isVisible)
        // Content area, not window frame: a title-bar-only window (~1x32 pt
        // frame) satisfied `frame.height > 0` while the sizing bug lived.
        #expect(window.contentLayoutRect.height >= 200)
        #expect(window.contentLayoutRect.width >= 400)
    }

    // Regression: the parameterless form must build a window, not fall
    // through to NSWindowController.init() with a nil window.
    @Test func parameterlessInitBuildsWindow() {
        let controller = SettingsWindowController()
        #expect(controller.window != nil)
    }
}
