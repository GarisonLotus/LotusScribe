import AppKit
import os

/// App lifecycle owner. Holds the status-item controller and hotkey monitor
/// for the app's lifetime.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "AppDelegate")

    private var statusItemController: StatusItemController?
    private var hotkeyController: HotkeyController?
    private var permissionsObserver: NSObjectProtocol?
    // Internal (not private) so the hosted smoke test can assert real
    // post-launch composition (R3).
    private(set) var dictationController: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Brand foundation first: register bundled fonts and force the stored
        // appearance (dark by default) before any window is built.
        LotusFonts.register()
        LotusAppearance.apply()
        MainMenu.install()
        // Icons Task 3: dev fallback so the Dock/app icon is the Lotus mark even
        // when the AppIcon asset catalog isn't compiled into the dev bundle.
        if let icon = AppIconRenderer.applicationIcon() {
            NSApplication.shared.applicationIconImage = icon
        }
        statusItemController = StatusItemController()
        Permissions.logStatusAtLaunch()

        // Hosted unit tests launch this app as their test host; requesting
        // listen access there would block `make test` behind a TCC dialog.
        // (Marker verified empirically: xcodebuild test sets XCTestSessionIdentifier.)
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
            // Input Monitoring is requested in main.swift BEFORE any AX check
            // (rdar://7381305 — requesting after AXIsProcessTrusted() no-ops),
            // and only when mic is already granted (returning user). Fresh /
            // mid-onboarding users get it solely from the onboarding "Allow…"
            // tap. Either way, do NOT request it here: logStatusAtLaunch()
            // above already called AXIsProcessTrusted(), so a request now is dead.

            // D42: launch warm-up — fire-and-forget, log-only; skipped
            // internally when cleanup is not effective-enabled.
            Task { await CleanupService(settings: SettingsStore()).warmUp() }

            // 7B (D67): first-run onboarding until Skip/Finish sets the
            // flag. Stays inside this guard — the real controller polls
            // live TCC, which must never run mid-`make test`. Routed
            // through StatusItemController, the sole controller owner
            // (R67 — no second window from "Rerun Onboarding…").
            if !SettingsStore().onboardingCompleted {
                statusItemController?.showOnboarding()
            }
        }

        let dictation = DictationController()
        // Spec §5 / icons Task 2: drive the full-color status icon's three
        // states (idle / listening glow+dot / processing pulse).
        dictation.onCaptureStateChanged = { [weak self] state in
            self?.statusItemController?.setState(state)
        }
        // D97: relay each dictation outcome as a notification so the onboarding
        // try-it view can observe it (spec §10E1) — keeps DictationController
        // NotificationCenter-free and window-agnostic; harmless bare ping when
        // no view is alive (mirrors onListeningChanged staying wired for life).
        dictation.onOutcome = { outcome in
            NotificationCenter.default.post(
                name: .lotusDictationOutcome, object: nil,
                userInfo: ["outcome": outcome.rawValue])
        }
        dictationController = dictation
        // D84: HotkeyController owns the tap and re-binds it live when the
        // hotkey setting changes; it resolves the chord from the store (F5
        // default, D80). Dictation wiring unchanged.
        let hotkey = HotkeyController { action in dictation.handle(action) }
        hotkeyController = hotkey
        // Start the tap ONLY when Input Monitoring is already granted. Creating
        // the .defaultTap without it prompts for Accessibility at launch AND
        // touches the AX/TCC subsystem — which (rdar://7381305) would make the
        // first Input Monitoring request no-op, breaking a fresh user's
        // onboarding "Allow…". A fresh user's tap comes up via
        // .lotusPermissionsChanged the moment onboarding grants IM. Preflight
        // only — hasListenEventAccess() reads no AX, so the latch is untouched.
        if Permissions.hasListenEventAccess() {
            hotkey.start()
        }
        // When onboarding grants Input Monitoring, bring the tap up live so the
        // hotkey works without a relaunch. Guarded on the grant so a Skip that
        // left IM ungranted never re-triggers the launch-time prompt path.
        permissionsObserver = NotificationCenter.default.addObserver(
            forName: .lotusPermissionsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard Permissions.hasListenEventAccess() else { return }
                self?.hotkeyController?.start()
            }
        }
    }
}
