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

    // D26/D37: probe success → Save writes all four D9 keys immediately
    // (empty → nil per D25), phase → success. The 2 s auto-close timer and
    // checkmark are thin UI, verified HUMAN-AT-SCREEN.
    @Test func savePersistsDraftsOnProbeSuccess() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(store: store, probe: { _, _ in .success })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.sttModel = "whisper-large-v3"
        controller.draft.llmEndpointURL = ""
        controller.draft.llmModel = "qwen3"
        controller.save()
        await controller.probeTask?.value

        #expect(store.sttEndpointURL == "https://stt.example.com/v1")
        #expect(store.sttModel == "whisper-large-v3")
        #expect(store.llmEndpointURL == nil)  // empty → nil (D25)
        #expect(store.llmModel == "qwen3")
        #expect(controller.probeState.phase == .success)
        controller.window?.close()  // don't sit out the 2 s auto-close
    }

    // D36: empty drafted STT URL → save+close exactly as before, probe never
    // invoked (clearing settings must not be blocked by a guaranteed fail).
    @Test func saveWithEmptySTTURLSkipsProbeAndCloses() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(store: store, probe: { _, _ in
            Issue.record("probe must not run for an empty drafted STT URL")
            return .failure(reason: "unexpected probe")
        })
        controller.show()

        controller.draft.sttModel = "whisper-large-v3"
        controller.save()

        #expect(controller.probeTask == nil)
        #expect(store.sttModel == "whisper-large-v3")
        #expect(controller.window?.isVisible == false)
    }

    // D37: probe failure → store untouched, phase carries the reason for
    // the sheet (the sheet itself is thin UI, verified HUMAN-AT-SCREEN).
    @Test func probeFailureLeavesStoreUntouched() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        store.sttModel = "before"
        let controller = SettingsWindowController(store: store, probe: { _, _ in
            .failure(reason: "HTTP 503")
        })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.sttModel = "edited"
        controller.save()
        await controller.probeTask?.value

        #expect(store.sttModel == "before")
        #expect(store.sttEndpointURL == nil)
        #expect(controller.probeState.phase == .failure("HTTP 503"))
        controller.window?.close()  // dismisses the failure sheet too
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
