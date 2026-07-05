import AppKit
import Testing
@testable import LotusScribe

/// Hosted tests for the pill's window behavior (spec §2B). Relies on the
/// xcodebuild test host's NSApp, same as SettingsWindowControllerTests
/// (R24 note). Size assertions use `contentLayoutRect`, never the window
/// frame (R23).
@MainActor
struct PillPanelTests {
    @Test func contentLayoutRectMeetsPillMetrics() {
        let controller = PillController()
        defer { controller.hide() }
        controller.show(.recording)

        let rect = controller.panel.contentLayoutRect
        #expect(rect.width >= PillMetrics.contentSize.width)
        #expect(rect.height >= PillMetrics.contentSize.height)
    }

    @Test func panelCanNeverBecomeKeyOrMain() {
        let panel = PillController().panel
        #expect(panel.canBecomeKey == false)
        #expect(panel.canBecomeMain == false)
    }

    @Test func panelBehaviorFlags() {
        let panel = PillController().panel
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(panel.ignoresMouseEvents)
        #expect(panel.hidesOnDeactivate == false)
    }

    @Test func showUpdateHideDriveStateAndVisibility() {
        let controller = PillController()
        #expect(controller.state == .hidden)

        controller.show(.warming)
        #expect(controller.state == .warming)
        #expect(controller.panel.isVisible)

        controller.update(.recording)
        #expect(controller.state == .recording)

        controller.hide()
        #expect(controller.state == .hidden)
        #expect(controller.panel.isVisible == false)
    }

    @Test func successFlashAutoHidesAfterFlashDuration() async throws {
        let controller = PillController()
        controller.show(.success)
        #expect(controller.state == .success)

        // Poll past flashDuration (0.8 s) with margin; the hide arrives via
        // an asyncAfter on the main queue, which runs while we're suspended.
        for _ in 0..<30 where controller.state != .hidden {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(controller.state == .hidden)
        #expect(controller.panel.isVisible == false)
    }
}
