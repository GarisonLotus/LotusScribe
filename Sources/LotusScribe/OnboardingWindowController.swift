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
    /// D90: the Setup step edits this buffered draft; `commitSetup()` is the
    /// only path that writes it to the store. Owned here like
    /// SettingsWindowController owns its draft — onboarding is a separate
    /// window/draft, so D26 (Settings-window Save invariant) is untouched.
    let draft: SettingsDraft
    /// D96 (§10D): the Setup step's read-only "Test connection" probe state.
    /// Reuses SettingsWindowController's ProbeState type — the Setup test is
    /// the same orchestration, published inline (never gates Continue).
    let probeState = ProbeState()

    private let settings: SettingsStore
    /// Injected TCC read (D14) so hosted tests poll a stub — production
    /// uses the real Permissions checks. Preflight-only: no request call
    /// ever fires from construction or the poll.
    private let snapshotProvider: () -> PermissionSnapshot
    /// Injected probe seams (D14) so the Setup test's sequential orchestration
    /// tests headlessly — identical to SettingsWindowController's Save seams.
    private let runSTTProbe: (String, String) async -> ProbeResult
    private let runLLMProbe: (String, String) async -> ProbeResult
    /// Exposed read-only so tests can fire a tick instead of waiting 1 s.
    private(set) var pollTimer: Timer?
    /// Exposed read-only so tests can await the Setup test's async probe leg.
    private(set) var probeTask: Task<Void, Never>?

    init(
        settings: SettingsStore = SettingsStore(),
        snapshotProvider: @escaping () -> PermissionSnapshot = Permissions.snapshot,
        sttProbe: @escaping (String, String) async -> ProbeResult = { endpoint, model in
            await ConnectionProbe().testSTT(endpoint: endpoint, model: model)
        },
        llmProbe: @escaping (String, String) async -> ProbeResult = { endpoint, model in
            await ConnectionProbe().testLLM(endpoint: endpoint, model: model)
        }
    ) {
        self.settings = settings
        self.snapshotProvider = snapshotProvider
        runSTTProbe = sttProbe
        runLLMProbe = llmProbe
        state = OnboardingState(snapshot: snapshotProvider())
        draft = SettingsDraft(store: settings)
        super.init(window: nil)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: OnboardingView(
                state: state,
                draft: draft,
                probeState: probeState,
                onSkip: { [weak self] in self?.skip() },
                onSetupCommit: { [weak self] in self?.commitSetup() },
                onSetupTest: { [weak self] in self?.testSetupConnection() },
                onFinish: { [weak self] in self?.finish() })))
        window.title = "Welcome to LotusScribe"
        // Fixed-size checklist: same macOS 26 fitting-size collapse as the
        // settings window — size the window from the view's constant (R40).
        window.setContentSize(OnboardingView.contentSize)
        window.styleMask.remove(.resizable)
        window.standardWindowButton(.zoomButton)?.isEnabled = false  // spec §4
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
        draft.reload()  // D90: re-seed Setup fields from the store on each show
        probeState.phase = .idle  // D96: reopen resets the Setup test indicator
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

    /// D90: Setup's Continue commits the drafted endpoints/models to the
    /// store. Explicit and UNGATED — the Setup step is skippable, so there is
    /// no probe gate and no D42 warm-up (first run, no live cleanup to warm).
    func commitSetup() {
        draft.save()
    }

    /// D96 (§10D): "Test connection" — probe the DRAFTED endpoints (STT then
    /// LLM) sequentially and publish the outcome inline, mirroring
    /// SettingsWindowController.test(). Read-only: never persists, never
    /// closes, never gates Continue (the Setup step is skippable). Both URLs
    /// empty → no-op.
    func testSetupConnection() {
        probeTask?.cancel()
        probeTask = nil

        let sttEndpoint = draft.sttEndpointURL
        let llmEndpoint = draft.llmEndpointURL
        guard !sttEndpoint.isEmpty || !llmEndpoint.isEmpty else { return }

        probeState.phase = .testing
        let sttModel = draft.sttModel
        let llmModel = draft.llmModel
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.probeEndpoints(
                sttEndpoint: sttEndpoint, sttModel: sttModel,
                llmEndpoint: llmEndpoint, llmModel: llmModel)
            // A mid-test close cancelled us — this leg owns nothing anymore.
            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                self.probeState.phase = .success
            case .failure(let reason):
                self.probeState.phase = .failure(reason)
            }
        }
    }

    /// D44/D96 sequential probes: skip empty URLs, stop at the first failure,
    /// prefix the reason with the endpoint's name (same shape as
    /// SettingsWindowController.probeEndpoints).
    private func probeEndpoints(
        sttEndpoint: String, sttModel: String,
        llmEndpoint: String, llmModel: String
    ) async -> ProbeResult {
        if !sttEndpoint.isEmpty,
           case .failure(let reason) = await runSTTProbe(sttEndpoint, sttModel) {
            return .failure(reason: "Speech to Text: \(reason)")
        }
        if !llmEndpoint.isEmpty,
           case .failure(let reason) = await runLLMProbe(llmEndpoint, llmModel) {
            return .failure(reason: "Cleanup LLM: \(reason)")
        }
        return .success
    }

    private func complete() {
        settings.onboardingCompleted = true
        // The user may have just granted Input Monitoring — tell AppDelegate to
        // bring the hotkey tap up live (it is not started at launch for an
        // ungranted user, to keep the AX subsystem clean for the IM request;
        // see AppDelegate / rdar://7381305).
        NotificationCenter.default.post(name: .lotusPermissionsChanged, object: nil)
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
        probeTask?.cancel()  // D96: nothing published after the window is gone
        probeTask = nil
    }
}
