import AppKit
import os
import SwiftUI

/// Live permission state republished to OnboardingView (D67: no TCC
/// change notifications exist, so the controller polls and pushes here).
@MainActor
final class OnboardingState: ObservableObject {
    @Published var snapshot: PermissionSnapshot

    init(snapshot: PermissionSnapshot) {
        self.snapshot = snapshot
    }
}

/// First-run onboarding window (spec docs/phase-7-spec.md §7B, D67):
/// checklist of the three TCC grants, shown at launch until
/// `onboardingCompleted` is set; "Rerun Onboarding…" reopens it
/// regardless. Skip and Finish both set the flag; Finish is additionally
/// gated all-green. New composition root on the launch path → R35
/// construction-smoke test owed (OnboardingWindowControllerTests).
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "OnboardingWindowController")

    let state: OnboardingState

    private let settings: SettingsStore
    /// Injected TCC read (D14) so hosted tests poll a stub — production
    /// uses the real Permissions checks. Preflight-only: no request call
    /// ever fires from construction or the poll.
    private let snapshotProvider: () -> PermissionSnapshot
    /// Exposed read-only so tests can fire a tick instead of waiting 1 s.
    private(set) var pollTimer: Timer?

    init(
        settings: SettingsStore = SettingsStore(),
        snapshotProvider: @escaping () -> PermissionSnapshot = Permissions.snapshot
    ) {
        self.settings = settings
        self.snapshotProvider = snapshotProvider
        state = OnboardingState(snapshot: snapshotProvider())
        super.init(window: nil)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: OnboardingView(
                state: state,
                onSkip: { [weak self] in self?.skip() },
                onFinish: { [weak self] in self?.finish() })))
        window.title = "Welcome to LotusScribe"
        // Fixed-size checklist: same macOS 26 fitting-size collapse as the
        // settings window — size the window from the view's constant (R40).
        window.setContentSize(OnboardingView.contentSize)
        window.styleMask.remove(.resizable)
        window.center()
        window.delegate = self  // windowWillClose stops the poll
        self.window = window
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// LSUIElement apps aren't active when this fires — activate first or
    /// the window appears behind the frontmost app without key focus
    /// (same reason as SettingsWindowController.show()).
    func show() {
        state.snapshot = snapshotProvider()  // fresh read before first tick
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        startPolling()
    }

    /// Finish is gated all-green (D67). The button is disabled short of
    /// `.done`; this guard keeps the invariant machine-testable and holds
    /// if a grant is revoked between the last tick and the click.
    func finish() {
        guard OnboardingStep.resolve(state.snapshot) == .done else { return }
        complete()
    }

    /// Skip: always available — sets the flag so launch stops showing the
    /// window (D67).
    func skip() {
        complete()
    }

    private func complete() {
        settings.onboardingCompleted = true
        window?.close()
    }

    /// 1 s poll while visible (D67: no TCC change notifications exist).
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            // Scheduled from the main thread → fires on the main run loop.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.state.snapshot = self.snapshotProvider()
            }
        }
    }

    /// Every close path (Skip, Finish, titlebar) lands here — stop the
    /// poll so a closed window never keeps repeating TCC checks alive.
    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
