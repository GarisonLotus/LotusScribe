import ApplicationServices
import CoreGraphics
import os

/// Thin wrappers around the TCC permission checks the event tap depends on
/// (D14 adapter — no branching logic, manually verified). No onboarding UI
/// in Phase 1 (that's Phase 7); grants happen via the system prompt or
/// System Settings toggles, recorded in docs/phase-1-tester-baselines.md.
enum Permissions {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "Permissions")

    /// True if the app may create listen-only event taps (Input Monitoring).
    static func hasListenEventAccess() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// Shows the Input Monitoring prompt if undetermined; returns current
    /// access. Never call from hosted-test launches (TCC dialog mid-test).
    static func requestListenEventAccess() -> Bool {
        CGRequestListenEventAccess()
    }

    /// True if the app is trusted for Accessibility. Never prompts.
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Launch-time TCC snapshot for the phase-1 empirical record (spec §1A verify 3).
    static func logStatusAtLaunch() {
        logger.info(
            "TCC at launch — listenEventAccess: \(hasListenEventAccess()), accessibilityTrusted: \(isAccessibilityTrusted())")
    }
}
