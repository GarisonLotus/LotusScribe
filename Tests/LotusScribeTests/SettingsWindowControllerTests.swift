import AppKit
import Foundation
import Testing
@testable import LotusScribe

/// Hosted tests: window materialization plus the D37/D44 Save flow with
/// injected stub probes and warm-up closure. Guards the live defect where
/// `SettingsWindowController()` resolved to the inherited
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
        // 390 pt content (form + picker + D26 button row); threshold tracks it.
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
        let controller = SettingsWindowController(store: store, sttProbe: { _, _ in .success })
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

    // D36/D44: both drafted endpoint URLs empty → save+close exactly as
    // before, no probe invoked (clearing settings must not be blocked by a
    // guaranteed fail).
    @Test func saveWithEmptyURLsSkipsProbesAndCloses() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let failProbe: (String, String) async -> ProbeResult = { _, _ in
            Issue.record("no probe may run when both drafted URLs are empty")
            return .failure(reason: "unexpected probe")
        }
        let controller = SettingsWindowController(
            store: store, sttProbe: failProbe, llmProbe: failProbe)
        controller.show()

        controller.draft.sttModel = "whisper-large-v3"
        controller.save()

        #expect(controller.probeTask == nil)
        #expect(store.sttModel == "whisper-large-v3")
        #expect(controller.window?.isVisible == false)
    }

    // D37/D44: probe failure → store untouched, phase carries the
    // endpoint-named reason for the sheet (the sheet itself is thin UI,
    // verified HUMAN-AT-SCREEN).
    @Test func probeFailureLeavesStoreUntouched() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        store.sttModel = "before"
        let controller = SettingsWindowController(store: store, sttProbe: { _, _ in
            .failure(reason: "HTTP 503")
        })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.sttModel = "edited"
        controller.save()
        await controller.probeTask?.value

        #expect(store.sttModel == "before")
        #expect(store.sttEndpointURL == nil)
        #expect(controller.probeState.phase == .failure("Speech to Text: HTTP 503"))
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

    // MARK: 3C — cleanup level picker binding (D40 through the D26 draft)

    // The picker binds through the buffered draft: reload resolves the
    // stored raw value, Save writes the rawValue — level changes are
    // Save-gated like every other field.
    @Test func cleanupLevelRoundTripsThroughDraft() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        store.cleanupLevel = "light"
        let controller = SettingsWindowController(store: store)
        controller.show()

        #expect(controller.draft.cleanupLevel == .light)

        controller.draft.cleanupLevel = .off
        controller.save()  // both URLs empty → immediate save+close

        #expect(store.cleanupLevel == "off")
        #expect(controller.window?.isVisible == false)
    }

    // MARK: 3C — per-endpoint Save probe (D44)

    // D44: an empty drafted LLM URL skips the LLM probe entirely
    // (level-independent empty-skip, mirroring D36).
    @Test func emptyLLMURLSkipsLLMProbe() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let controller = SettingsWindowController(
            store: SettingsStore(defaults: defaults),
            sttProbe: { _, _ in .success },
            llmProbe: { _, _ in
                Issue.record("LLM probe must not run for an empty drafted LLM URL")
                return .failure(reason: "unexpected probe")
            })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.save()
        await controller.probeTask?.value

        #expect(controller.probeState.phase == .success)
        controller.window?.close()
    }

    // D44: probes run STT first and stop at its failure — the LLM probe
    // never runs, and the reason names the failing endpoint for the sheet.
    @Test func sttFailureStopsChainBeforeLLMProbe() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let controller = SettingsWindowController(
            store: SettingsStore(defaults: defaults),
            sttProbe: { _, _ in .failure(reason: "HTTP 503") },
            llmProbe: { _, _ in
                Issue.record("LLM probe must not run after an STT failure")
                return .success
            })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.llmEndpointURL = "https://llm.example.com/v1"
        controller.save()
        await controller.probeTask?.value

        #expect(controller.probeState.phase == .failure("Speech to Text: HTTP 503"))
        controller.window?.close()
    }

    // D44: an LLM failure names its endpoint too; store untouched (D37).
    @Test func llmFailureNamesEndpointAndWritesNothing() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(
            store: store,
            sttProbe: { _, _ in .success },
            llmProbe: { _, _ in .failure(reason: "HTTP 404") })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.llmEndpointURL = "https://llm.example.com/v1"
        controller.save()
        await controller.probeTask?.value

        #expect(controller.probeState.phase == .failure("Cleanup LLM: HTTP 404"))
        #expect(store.llmEndpointURL == nil)
        controller.window?.close()
    }

    // D44: both endpoints drafted and green → one save, success phase.
    @Test func bothProbesGreenPersistsAndSucceeds() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        let controller = SettingsWindowController(
            store: store,
            sttProbe: { _, _ in .success },
            llmProbe: { _, _ in .success },
            warmUp: {})  // save changes the LLM config — keep warm-up stubbed
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.draft.llmEndpointURL = "https://llm.example.com/v1"
        controller.draft.llmModel = "qwen3"
        controller.save()
        await controller.probeTask?.value

        #expect(store.sttEndpointURL == "https://stt.example.com/v1")
        #expect(store.llmEndpointURL == "https://llm.example.com/v1")
        #expect(controller.probeState.phase == .success)
        controller.window?.close()
    }

    // MARK: 3C — endpoint-change warm-up (D42)

    // D42: a save that changes llmEndpointURL/llmModel while cleanup is
    // effective-enabled fires the warm-up closure exactly once.
    @Test func llmChangeSaveFiresWarmUpOnce() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        var warmUpCount = 0
        let controller = SettingsWindowController(
            store: SettingsStore(defaults: defaults),
            sttProbe: { _, _ in .success },
            llmProbe: { _, _ in .success },
            warmUp: { warmUpCount += 1 })
        controller.show()

        controller.draft.llmEndpointURL = "https://llm.example.com/v1"
        controller.draft.llmModel = "qwen3"
        controller.save()
        await controller.probeTask?.value

        #expect(controller.probeState.phase == .success)
        #expect(warmUpCount == 1)
        controller.window?.close()
    }

    // D42: a save that leaves the LLM config unchanged fires no warm-up.
    @Test func noChangeSaveFiresNoWarmUp() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = SettingsStore(defaults: defaults)
        store.llmEndpointURL = "https://llm.example.com/v1"
        store.llmModel = "qwen3"
        var warmUpCount = 0
        let controller = SettingsWindowController(
            store: store,
            sttProbe: { _, _ in .success },
            llmProbe: { _, _ in .success },
            warmUp: { warmUpCount += 1 })
        controller.show()  // reload seeds drafts with the stored values

        controller.save()
        await controller.probeTask?.value

        #expect(controller.probeState.phase == .success)
        #expect(warmUpCount == 0)
        controller.window?.close()
    }

    // MARK: R36 — re-entrant Save cancels stale flash tasks

    // R36 regression: a Save clicked during the 2 s success flash must
    // cancel the stale auto-close, or the window vanishes mid-second-probe.
    @Test func reentrantSaveCancelsStaleAutoClose() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let controller = SettingsWindowController(
            store: SettingsStore(defaults: defaults),
            sttProbe: { _, _ in .success })
        controller.show()

        controller.draft.sttEndpointURL = "https://stt.example.com/v1"
        controller.save()
        await controller.probeTask?.value
        let staleAutoClose = try #require(controller.autoCloseTask)

        controller.save()  // re-entry during the success flash
        #expect(staleAutoClose.isCancelled)
        await controller.probeTask?.value

        // The stale flash's close never fires — the window survives the
        // second probe.
        #expect(controller.window?.isVisible == true)
        controller.window?.close()
    }
}
