import Foundation

/// Pure onboarding state (spec docs/phase-7-spec.md §7B, D67 — the D40
/// pure-enum shape). Foundation-only: the TCC reads live in
/// Permissions.snapshot() (D14 adapter); this file is the headless truth
/// table the checklist window renders from.

/// One point-in-time read of the three TCC grants the app depends on.
struct PermissionSnapshot {
    let micGranted: Bool
    let accessibilityTrusted: Bool
    let listenEventGranted: Bool
}

/// The checklist's "current" row. Input Monitoring is UNCONDITIONAL (D68:
/// phase-1 empirical record — BOTH IM and AX are required for tap delivery).
///
/// Order is mic → inputMonitoring → accessibility, and that order is
/// LOAD-BEARING (rdar://7381305): the first Input Monitoring request must
/// precede any `AXIsProcessTrusted()` read, so IM is surfaced before
/// Accessibility — the Accessibility row's live state is withheld
/// (Permissions.isAccessibilityTrusted latch) until the user taps IM "Allow…".
enum OnboardingStep: Equatable {
    case mic, accessibility, inputMonitoring, done

    /// First ungranted permission in order mic → inputMonitoring →
    /// accessibility; all granted → `.done`.
    static func resolve(_ s: PermissionSnapshot) -> OnboardingStep {
        if !s.micGranted { return .mic }
        if !s.listenEventGranted { return .inputMonitoring }
        if !s.accessibilityTrusted { return .accessibility }
        return .done
    }
}
