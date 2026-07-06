import AppKit
import os

/// App lifecycle owner. Holds the status-item controller and hotkey monitor
/// for the app's lifetime.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "AppDelegate")

    private var statusItemController: StatusItemController?
    private var hotkeyController: HotkeyController?
    // Internal (not private) so the hosted smoke test can assert real
    // post-launch composition (R3).
    private(set) var dictationController: DictationController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Brand foundation first: register bundled fonts and force the stored
        // appearance (dark by default) before any window is built.
        LotusFonts.register()
        LotusAppearance.apply()
        MainMenu.install()
        statusItemController = StatusItemController()
        Permissions.logStatusAtLaunch()

        // Hosted unit tests launch this app as their test host; requesting
        // listen access there would block `make test` behind a TCC dialog.
        // (Marker verified empirically: xcodebuild test sets XCTestSessionIdentifier.)
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
            // Only fire the Input Monitoring ("Keystroke Receiving") prompt at
            // launch for established users — mic-granted is the proxy for
            // "already onboarded". First-run users (mic not yet granted) get
            // this prompt in context from onboarding's Input Monitoring button
            // instead, so it's never a surprise on the very first launch.
            if Permissions.isMicrophoneGranted() {
                _ = Permissions.requestListenEventAccess()
            }

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
        // Spec §5: tint the status-item lotus magenta while the mic is capturing.
        dictation.onListeningChanged = { [weak self] listening in
            self?.statusItemController?.setListening(listening)
        }
        dictationController = dictation
        // D84: HotkeyController owns the tap and re-binds it live when the
        // hotkey setting changes; it resolves the chord from the store (F5
        // default, D80). Dictation wiring unchanged.
        let hotkey = HotkeyController { action in dictation.handle(action) }
        hotkeyController = hotkey
        hotkey.start()
    }
}
