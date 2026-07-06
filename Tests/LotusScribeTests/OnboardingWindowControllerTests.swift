import AppKit
import Foundation
import Testing
@testable import LotusScribe

/// Hosted tests for the onboarding window (7B, D67). Every controller is
/// built with a STUBBED snapshot provider so no live TCC is read, and no
/// request can fire (R35 posture: request calls only fire from button
/// taps, which these tests never press).
@MainActor
final class OnboardingWindowControllerTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private static let allDenied = PermissionSnapshot(
        micGranted: false, accessibilityTrusted: false, listenEventGranted: false)
    private static let allGranted = PermissionSnapshot(
        micGranted: true, accessibilityTrusted: true, listenEventGranted: true)

    private func makeStore() throws -> SettingsStore {
        SettingsStore(defaults: try #require(UserDefaults(suiteName: suiteName)))
    }

    // R35 construction smoke: new composition root on the launch path —
    // the window materializes at the D67 checklist size, shows, closes.
    @Test func constructionSmokeShowsAndCloses() throws {
        let controller = OnboardingWindowController(
            settings: try makeStore(), snapshotProvider: { Self.allDenied })
        controller.show()
        defer { controller.window?.close() }

        let window = try #require(controller.window)
        #expect(window.isVisible)
        // Content area, not window frame (the settings-window sizing-bug
        // lesson): ~480×420 content per D67; thresholds track it.
        #expect(window.contentLayoutRect.width >= 400)
        #expect(window.contentLayoutRect.height >= 350)
    }

    // D67: each 1 s poll tick republishes the provider's current answer —
    // the test fires the timer directly instead of waiting the second out.
    @Test func pollTickRepublishesSnapshotAndAdvancesStep() throws {
        var current = Self.allDenied
        let controller = OnboardingWindowController(
            settings: try makeStore(), snapshotProvider: { current })
        controller.show()
        defer { controller.window?.close() }

        #expect(OnboardingStep.resolve(controller.state.snapshot) == .mic)
        let timer = try #require(controller.pollTimer)
        #expect(timer.timeInterval == 1)

        current = PermissionSnapshot(
            micGranted: true, accessibilityTrusted: false, listenEventGranted: false)
        timer.fire()

        #expect(OnboardingStep.resolve(controller.state.snapshot) == .accessibility)
    }

    // D67: Finish is gated all-green — short of .done it's a no-op (flag
    // unset, window still open).
    @Test func finishBeforeDoneIsNoOp() throws {
        let store = try makeStore()
        let controller = OnboardingWindowController(
            settings: store, snapshotProvider: { Self.allDenied })
        controller.show()
        defer { controller.window?.close() }

        controller.finish()

        #expect(store.onboardingCompleted == false)
        #expect(controller.window?.isVisible == true)
    }

    // D67: Finish at .done sets the flag and closes.
    @Test func finishAtDoneSetsFlagAndCloses() throws {
        let store = try makeStore()
        let controller = OnboardingWindowController(
            settings: store, snapshotProvider: { Self.allGranted })
        controller.show()

        controller.finish()

        #expect(store.onboardingCompleted == true)
        #expect(controller.window?.isVisible == false)
    }

    // D67: Skip always completes — flag set and window closed even with
    // every grant still red.
    @Test func skipSetsFlagAndCloses() throws {
        let store = try makeStore()
        let controller = OnboardingWindowController(
            settings: store, snapshotProvider: { Self.allDenied })
        controller.show()

        controller.skip()

        #expect(store.onboardingCompleted == true)
        #expect(controller.window?.isVisible == false)
    }

    // Every close path stops the poll — a closed window must never keep
    // repeating TCC checks alive (windowWillClose invalidates).
    @Test func closeStopsPolling() throws {
        let controller = OnboardingWindowController(
            settings: try makeStore(), snapshotProvider: { Self.allDenied })
        controller.show()
        #expect(controller.pollTimer != nil)

        controller.window?.close()

        #expect(controller.pollTimer == nil)
    }
}
