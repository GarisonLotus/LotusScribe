import ApplicationServices
import AVFoundation
import CoreGraphics
import IOKit.hid
import os

/// Thin wrappers around the TCC permission checks the event tap depends on
/// (D14 adapter — no branching logic, manually verified). No onboarding UI
/// in Phase 1 (that's Phase 7); grants happen via the system prompt or
/// System Settings toggles, recorded in docs/phase-1-tester-baselines.md.
enum Permissions {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "Permissions")

    /// True only if Input Monitoring is actually GRANTED.
    ///
    /// NOT `CGPreflightListenEventAccess()`: that is optimistic — it returns
    /// true for the *undetermined* state (never requested), so a fresh user's
    /// onboarding row falsely reads "Granted" and the launch tap-gate fires on
    /// a phantom grant. `IOHIDCheckAccess` distinguishes granted / denied /
    /// unknown, so undetermined correctly reads false. A pure read — no prompt,
    /// no AX touch — safe to call before the first request.
    static func hasListenEventAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Shows the Input Monitoring prompt if undetermined, and — load-bearing —
    /// REGISTERS the app into the Input Monitoring pane's list (row appears,
    /// toggled off) even when no dialog fires. Returns current access. Never
    /// call from hosted-test launches (TCC dialog mid-test).
    ///
    /// IOHIDRequestAccess, NOT CGRequestListenEventAccess: tccd-log-verified
    /// on macOS 26 that the CG call returns false without ever sending an
    /// AUTHREQ to the daemon — no prompt, no registration, no pane row (same
    /// platform-rot family as D27's dead fn events). The IOKit request is
    /// the path that actually reaches tccd.
    ///
    /// ORDERING IS LOAD-BEARING (rdar://7381305): this MUST run before any
    /// `AXIsProcessTrusted()` call in the process, or it silently no-ops — no
    /// prompt, no registration (empirically confirmed: the standalone
    /// onboarding "Allow…" tap produces zero tccd activity once AX was read
    /// earlier). main.swift fires it first for mic-granted users; for a fresh
    /// user the `listenEventRequested` latch below withholds every AX read
    /// until this runs, so the onboarding tap is still the first AX-free path.
    static func requestListenEventAccess() -> Bool {
        listenEventRequested = true
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Opened by the first `requestListenEventAccess()` of the process. Until
    /// then no `AXIsProcessTrusted()` may run (rdar://7381305) — see below.
    private static var listenEventRequested = false

    /// True if the app is trusted for Accessibility. Never prompts.
    ///
    /// Reports `false` WITHOUT touching `AXIsProcessTrusted()` until Input
    /// Monitoring has been requested at least once (the `listenEventRequested`
    /// latch). This is what lets a brand-new user's Input Monitoring "Allow…"
    /// tap register at all: were `logStatusAtLaunch()` or the onboarding poll
    /// to read AX first, that first IM request would silently no-op. The poll
    /// re-reads live and the Accessibility row resolves the instant the latch
    /// opens.
    static func isAccessibilityTrusted() -> Bool {
        // Safe to read AX once the rdar ordering concern is moot: either we
        // already fired the first IM request this session, OR Input Monitoring
        // is already granted (no pending first-registration to protect). The
        // second clause is load-bearing for the IM-already-granted user — the
        // "Allow…" never appears for them, so the latch would otherwise never
        // open and Accessibility would read false forever. (hasListenEventAccess
        // is IOHIDCheckAccess — a read, not an AX touch — so it is rdar-safe.)
        guard listenEventRequested || hasListenEventAccess() else { return false }
        return AXIsProcessTrusted()
    }

    /// True if the app may capture audio (Microphone). Never prompts —
    /// the request fires only from the onboarding mic button (7B, D68).
    static func isMicrophoneGranted() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// One point-in-time read of all three grants for the onboarding
    /// checklist poll (7B, D67).
    static func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            micGranted: isMicrophoneGranted(),
            accessibilityTrusted: isAccessibilityTrusted(),
            listenEventGranted: hasListenEventAccess())
    }

    /// Launch-time TCC snapshot for the phase-1 empirical record (spec §1A verify 3).
    static func logStatusAtLaunch() {
        logger.info(
            "TCC at launch — listenEventAccess: \(hasListenEventAccess()), accessibilityTrusted: \(isAccessibilityTrusted())")
    }
}
