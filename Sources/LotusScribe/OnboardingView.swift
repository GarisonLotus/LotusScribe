import AppKit
import AVFoundation
import SwiftUI

/// First-run onboarding, reskinned to "Lotus Bloom" as a 3-step flow
/// (DESIGN_SPEC.md §5): Welcome → Permissions → Try it. The permission logic
/// is unchanged from the original single-checklist version — same live
/// `state.snapshot`, same `OnboardingStep.resolve` highlighting, same real mic
/// prompt and System-Settings deep links (D68), same Finish gate on all-green
/// (D67). Only the presentation and step structure changed; Skip/Finish
/// actions still come from the controller.
struct OnboardingView: View {
    /// Single source for the fixed onboarding window content size (R40 idiom).
    static let contentSize = CGSize(width: 480, height: 480)

    /// System Settings deep links (spec §7B exact URLs).
    private static let accessibilityPane =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let inputMonitoringPane =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"

    @ObservedObject var state: OnboardingState
    let onSkip: () -> Void
    let onFinish: () -> Void

    /// Which of the three steps is on screen (0 Welcome, 1 Permissions, 2 Try).
    @State private var stepIndex = 0

    /// Live label for the HUD-preview hotkey chip, tracking the persisted
    /// choice so picking a key on this step updates the preview (Phase 9).
    @State private var hotkeyLabel =
        HotkeyOption.from(persisted: SettingsStore().hotkeyChord).displayLabel

    /// Live permission resolution (unchanged) — gates Finish and highlights
    /// the current permission row.
    private var permissionStep: OnboardingStep { OnboardingStep.resolve(state.snapshot) }

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            progressDots
                .padding(.vertical, 12)
            navBar
        }
        .padding(28)
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
        .lotusWindowBackground()
        .onReceive(NotificationCenter.default.publisher(for: .lotusHotkeyChanged)) { _ in
            hotkeyLabel = HotkeyOption.from(persisted: SettingsStore().hotkeyChord).displayLabel
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch stepIndex {
        case 0: welcomeStep
        case 1: permissionsStep
        default: tryItStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            Spacer()
            LotusMark(size: 52)
            kicker("STEP 1 OF 3")
            Text("Talk. It types.")
                .font(.lotusDisplay(38))
                .lineSpacing(3)  // ~1.08 line-height
                .foregroundStyle(Color.lotusTextPrimary)
                .multilineTextAlignment(.center)
            Text("Hold your hotkey, speak, and LotusScribe transcribes, cleans up, and inserts the text right where your cursor is.")
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            kicker("STEP 2 OF 3")
            Text("Grant permissions")
                .font(.lotusDisplay(26))
                .foregroundStyle(Color.lotusTextPrimary)

            permissionRow(
                granted: state.snapshot.micGranted, current: permissionStep == .mic,
                title: "Microphone",
                detail: "Records your voice while the hotkey is held.",
                buttonTitle: "Allow…") {
                // D68: the one real TCC prompt — fires only from this tap.
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
            permissionRow(
                granted: state.snapshot.accessibilityTrusted, current: permissionStep == .accessibility,
                title: "Accessibility",
                detail: "Lets the hotkey listener and text insertion work. Enable LotusScribe in the list.",
                buttonTitle: "Open Settings…") {
                open(Self.accessibilityPane)
            }
            permissionRow(
                granted: state.snapshot.listenEventGranted, current: permissionStep == .inputMonitoring,
                title: "Input Monitoring",
                detail: "Lets LotusScribe see the dictation hotkey. Grant access when prompted, or enable LotusScribe in the list.",
                buttonTitle: "Allow…") {
                // Fire the system request and GET OUT OF ITS WAY. Do NOT open
                // System Settings here: requestListenEventAccess() returns
                // false the instant the async prompt starts showing, so a
                // follow-up open() slammed Settings over the prompt and killed
                // it every time. The onboarding poll picks up the grant.
                _ = Permissions.requestListenEventAccess()
            }
            Spacer(minLength: 0)
        }
    }

    private var tryItStep: some View {
        VStack(spacing: 14) {
            kicker("STEP 3 OF 3")
            Text("Try it")
                .font(.lotusDisplay(26))
                .foregroundStyle(Color.lotusTextPrimary)
            Text("Choose your hotkey, then hold \(hotkeyLabel) and talk:")
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
                .multilineTextAlignment(.center)
            // 9E (D86): the picker warns inline (with Settings deep links)
            // when the chosen key collides with a macOS shortcut — the static
            // F5 footnote it replaces only ever described one collision.
            HotkeyPicker()
            hudPreview
            Spacer(minLength: 0)
        }
    }

    // MARK: - Progress + navigation

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i == stepIndex
                        ? AnyShapeStyle(Color.lotusAccentText)
                        : AnyShapeStyle(Color.lotusControlFill))
                    .frame(width: 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private var navBar: some View {
        HStack {
            switch stepIndex {
            case 0:
                Button("Skip", action: onSkip)
                    .buttonStyle(LotusButtonStyle(.ghost))
                Spacer()
                Button("Get Started") { stepIndex = 1 }
                    .buttonStyle(LotusButtonStyle(.primary))
            case 1:
                Button("Back") { stepIndex = 0 }
                    .buttonStyle(LotusButtonStyle(.ghost))
                Spacer()
                Button("Continue") { stepIndex = 2 }
                    .buttonStyle(LotusButtonStyle(.primary))
            default:
                Button("Back") { stepIndex = 1 }
                    .buttonStyle(LotusButtonStyle(.ghost))
                Spacer()
                Button("Finish", action: onFinish)
                    .buttonStyle(LotusButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(permissionStep != .done)  // D67: gated all-green
            }
        }
    }

    // MARK: - Pieces

    private func kicker(_ text: String) -> some View {
        Text(text)
            .font(.lotusMono(11))
            .tracking(1.5)  // ~+14%
            .foregroundStyle(Color.lotusAccentText)
    }

    /// One permission row: 26pt outlined/filled circle-check + name + detail,
    /// and either "Granted" (mono accent) or the row's action button.
    private func permissionRow(
        granted: Bool, current: Bool, title: String, detail: String,
        buttonTitle: String, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 26))
                .foregroundStyle(granted
                    ? AnyShapeStyle(LinearGradient.lotusAccent)
                    : AnyShapeStyle(Color.lotusTextTertiary))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lotusBody)
                    .fontWeight(current ? .semibold : .regular)
                    .foregroundStyle(Color.lotusTextPrimary)
                Text(detail)
                    .font(.lotusCaption)
                    .foregroundStyle(Color.lotusTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if granted {
                Text("Granted")
                    .font(.lotusMono(11))
                    .foregroundStyle(Color.lotusAccentText)
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(LotusButtonStyle(.ghost))
            }
        }
    }

    /// A non-interactive preview of the Listening HUD (spec §5): mic dot +
    /// gradient waveform + LISTENING + the selected-hotkey chip. Animated
    /// unless Reduce Motion is on.
    private var hudPreview: some View {
        HUDPreview(hotkeyLabel: hotkeyLabel)
    }

    private func open(_ deepLink: String) {
        guard let url = URL(string: deepLink) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Static/animated mini-HUD shown on the onboarding "Try it" step. Purely
/// decorative — no audio, no panel; it just shows the user what Listening
/// looks like.
private struct HUDPreview: View {
    let hotkeyLabel: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let barCount = 12

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.lotusAccentPink)
                .frame(width: 7, height: 7)
            if reduceMotion {
                bars { i in 0.3 + 0.5 * abs(sin(Double(i))) }
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    bars { i in 0.25 + 0.65 * abs(sin(t * 6 + Double(i) * 0.7)) }
                }
            }
            Text("LISTENING")
                .font(.lotusMono(11))
                .tracking(1.2)
                .foregroundStyle(Color.lotusTextPrimary)
            Text(hotkeyLabel)
                .font(.lotusMono(11))
                .foregroundStyle(Color.lotusTextSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.lotusControlFill, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.lotusHUDFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
    }

    private func bars(_ height: @escaping (Int) -> Double) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient.lotusAccent)
                    .frame(width: 3, height: 4 + CGFloat(height(i)) * 18)
            }
        }
        .frame(height: 22)
    }
}
