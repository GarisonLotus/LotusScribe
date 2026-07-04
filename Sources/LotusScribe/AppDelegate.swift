import AppKit
import os

/// App lifecycle owner. Holds the status-item controller and hotkey monitor
/// for the app's lifetime.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "AppDelegate")

    private var statusItemController: StatusItemController?
    private var hotkeyMonitor: EventTapMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController()
        Permissions.logStatusAtLaunch()

        // Hosted unit tests launch this app as their test host; requesting
        // listen access there would block `make test` behind a TCC dialog.
        // (Marker verified empirically: xcodebuild test sets XCTestSessionIdentifier.)
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
            _ = Permissions.requestListenEventAccess()
        }

        // D15: chord from the `hotkeyChord` defaults key; nil/unparseable → hold-Fn.
        let chord = UserDefaults.standard.string(forKey: "hotkeyChord")
            .flatMap(HotkeyChord.parse) ?? .fnHold
        hotkeyMonitor = EventTapMonitor(chord: chord) { action in
            Self.logger.info("hotkey action: \(String(describing: action), privacy: .public)")
        }
        hotkeyMonitor?.start()
    }
}
