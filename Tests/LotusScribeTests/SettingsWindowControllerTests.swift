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
        // 350 pt content (form + D26 button row); threshold tracks it.
        #expect(window.contentLayoutRect.height >= 250)
        #expect(window.contentLayoutRect.width >= 400)
    }

    // Regression: the parameterless form must build a window, not fall
    // through to NSWindowController.init() with a nil window.
    @Test func parameterlessInitBuildsWindow() {
        let controller = SettingsWindowController()
        #expect(controller.window != nil)
    }

    // D26: Save writes all four D9 keys (empty → nil per D25) and closes.
    // Drives the same method the Save button calls.
    @Test func savePersistsDraftsAndCloses() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(store: store)
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.sttModel = "whisper-large-v3"
        controller.draft.llmEndpointURL = ""
        controller.draft.llmModel = "qwen3"
        controller.save()

        #expect(store.sttEndpointURL == "https://stt.example.com/v1")
        #expect(store.sttModel == "whisper-large-v3")
        #expect(store.llmEndpointURL == nil)  // empty → nil (D25)
        #expect(store.llmModel == "qwen3")
        #expect(controller.window?.isVisible == false)
    }

    // D26: Cancel closes and writes nothing — the store stays untouched.
    @Test func cancelWritesNothingAndCloses() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        store.sttModel = "before"
        let controller = SettingsWindowController(store: store)
        controller.show()

        controller.draft.sttModel = "edited but abandoned"
        controller.draft.sttEndpointURL = "https://never.example.com"
        controller.cancel()

        #expect(store.sttModel == "before")
        #expect(store.sttEndpointURL == nil)
        #expect(controller.window?.isVisible == false)
    }

    // D26: reopening re-seeds drafts from the store — abandoned edits are
    // gone, and values changed behind the pane's back show up.
    @Test func reopenReseedsDraftsFromStore() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(store: store)
        controller.show()
        controller.draft.sttModel = "abandoned edit"
        controller.cancel()

        store.sttModel = "external value"
        controller.show()
        defer { controller.window?.close() }

        #expect(controller.draft.sttModel == "external value")
        #expect(controller.draft.sttEndpointURL == "")
    }
}
