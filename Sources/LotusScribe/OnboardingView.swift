import AppKit
import AVFoundation
import SwiftUI

/// First-run onboarding checklist (spec docs/phase-7-spec.md §7B, D67).
/// Three permission rows with live status glyphs; `OnboardingStep.resolve`
/// highlights the current row. Mic is the only real prompt; AX/IM rows
/// deep-link into System Settings (D68 — no request API prompts for them).
/// Thin UI: all state arrives via OnboardingState; Skip/Finish actions
/// come from the controller.
struct OnboardingView: View {
    /// Single source for the fixed onboarding window content size (R40
    /// idiom — shared with the controller's setContentSize).
    static let contentSize = CGSize(width: 480, height: 420)

    /// System Settings deep links (spec §7B exact URLs).
    private static let accessibilityPane =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let inputMonitoringPane =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    private static let keyboardPane =
        "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"

    @ObservedObject var state: OnboardingState
    let onSkip: () -> Void
    let onFinish: () -> Void

    private var step: OnboardingStep { OnboardingStep.resolve(state.snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LotusScribe needs three permissions before hold-to-dictate works everywhere.")
                .font(.headline)

            row(granted: state.snapshot.micGranted, current: step == .mic,
                title: "Microphone",
                detail: "Records your voice while the hotkey is held.",
                buttonTitle: "Allow Microphone…") {
                // D68: the one real TCC prompt — fires only from this tap.
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
            row(granted: state.snapshot.accessibilityTrusted, current: step == .accessibility,
                title: "Accessibility",
                detail: "Lets the hotkey listener and text insertion work. Enable LotusScribe in the list.",
                buttonTitle: "Open System Settings…") {
                open(Self.accessibilityPane)
            }
            row(granted: state.snapshot.listenEventGranted, current: step == .inputMonitoring,
                title: "Input Monitoring",
                detail: "Lets LotusScribe see the dictation hotkey. Enable LotusScribe in the list.",
                buttonTitle: "Open System Settings…") {
                open(Self.inputMonitoringPane)
            }

            if step == .done {
                // Q7-4: whether tap delivery starts without relaunch is an
                // at-screen verify — hint copy adjusts once answered.
                Text("All set. If the hotkey doesn't respond, quit and reopen LotusScribe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // D27: macOS 26 uses the chord — Fn guidance only, no setting.
            HStack(alignment: .firstTextBaseline) {
                Text("Using the Fn key on older macOS? Set System Settings → Keyboard → “Press fn key to” → “Do Nothing”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open Keyboard Settings…") { open(Self.keyboardPane) }
            }

            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                Button("Finish", action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .disabled(step != .done)  // D67: gated all-green
            }
        }
        .padding(20)
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }

    /// One checklist row: status glyph, title (current row bolded),
    /// caption detail, and the row's action while ungranted.
    private func row(
        granted: Bool, current: Bool, title: String, detail: String,
        buttonTitle: String, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(current ? .semibold : .regular)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button(buttonTitle, action: action)
            }
        }
    }

    private func open(_ deepLink: String) {
        guard let url = URL(string: deepLink) else { return }
        NSWorkspace.shared.open(url)
    }
}
