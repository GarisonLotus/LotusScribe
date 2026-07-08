import os
import ServiceManagement

/// "Open at Login" via `SMAppService.mainApp` (macOS 13+). The OS is the source
/// of truth — `isEnabled` reads the live registration status (so a change made
/// in System Settings › General › Login Items is reflected), and `setEnabled`
/// registers/unregisters. No helper bundle or entitlement is needed for the
/// main app. Failures are logged, not thrown to callers: a login item is a
/// convenience, never worth interrupting a flow over.
enum LaunchAtLogin {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "LaunchAtLogin")

    /// True when the app is currently registered to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register (true) or unregister (false) the app as a login item. Idempotent
    /// and best-effort: any error is logged and swallowed so the caller's UI
    /// (a toggle) simply re-reads `isEnabled` to reflect what actually stuck.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Open at Login \(enabled ? "register" : "unregister", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
