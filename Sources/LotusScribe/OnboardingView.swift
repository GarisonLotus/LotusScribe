import AppKit
import AVFoundation
import SwiftUI

/// First-run onboarding, reskinned to "Lotus Bloom" as a 4-step flow
/// (DESIGN_SPEC.md §5): Welcome → Permissions → Setup → Try it. The permission logic
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
    /// D90: buffered Setup-step draft, owned by the controller. Continue
    /// commits it via `onSetupCommit`; the fields edit it locally until then.
    @ObservedObject var draft: SettingsDraft
    let onSkip: () -> Void
    let onSetupCommit: () -> Void
    let onFinish: () -> Void

    /// Which step is on screen (0 Welcome, 1 Permissions, 2 Setup, 3 Try).
    @State private var stepIndex = 0

    /// Live label for the try-it prompt/hotkey chip, tracking the persisted
    /// choice so picking a key on this step updates the copy (Phase 9).
    @State private var hotkeyLabel =
        HotkeyOption.from(persisted: SettingsStore().hotkeyChord).displayLabel

    /// D99: the real insertion target on the Try-it step — a focused, editable
    /// box a live dictation self-inserts into (replaces the decorative HUD).
    @State private var tryItText = ""

    /// D98: first-responder flag for the try-it box. Only true while the
    /// Try-it step is on screen so it never fights the picker's own field for
    /// focus; a synthesized Cmd-V needs the box to be first responder to land.
    @FocusState private var tryItFocused: Bool

    /// D97: last observed dictation outcome, decoded from
    /// `.lotusDictationOutcome`. Drives the inline setup hint via the pure
    /// `shouldShowSetupHint` predicate; `.inserted` clears it.
    @State private var lastOutcome: DictationController.DictationOutcome?

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
        // D97: relay each dictation outcome into the inline hint. userInfo
        // carries the DictationOutcome rawValue (D97) — decode it back to the
        // enum. SwiftUI tears this down when the window closes, so a closed
        // window never reacts (no manual clear needed).
        .onReceive(NotificationCenter.default.publisher(for: .lotusDictationOutcome)) { note in
            lastOutcome = (note.userInfo?["outcome"] as? String)
                .flatMap(DictationController.DictationOutcome.init(rawValue:))
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch stepIndex {
        case 0: welcomeStep
        case 1: permissionsStep
        // D93: Setup inserted before "Try it" so servers can be configured
        // before the user tries dictating (skippable — see navBar case 2).
        case 2: setupStep
        default: tryItStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 14) {
            Spacer()
            LotusMark(size: 52)
            kicker("STEP 1 OF 4")
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
            kicker("STEP 2 OF 4")
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

    private var setupStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kicker("STEP 3 OF 4")
                Text("Set up your servers")
                    .font(.lotusDisplay(26))
                    .foregroundStyle(Color.lotusTextPrimary)
                // D90: one-tap prefill of the featured stack (Speaches + Ollama)
                // into the buffered draft — endpoints AND suggested models.
                Button("Use recommended (Speaches + Ollama)") {
                    Self.applyRecommended(to: draft)
                }
                .buttonStyle(LotusButtonStyle(.primary))
                // Same field idioms as the Settings pane (D90 reuse), bound to
                // the onboarding draft. Install cards + Test are 10D.
                LotusCard {
                    VStack(alignment: .leading, spacing: 12) {
                        endpointField("Speech to Text endpoint", text: $draft.sttEndpointURL)
                        labeledField("Model") { monoField("model name", text: $draft.sttModel) }
                        endpointField("Cleanup LLM endpoint", text: $draft.llmEndpointURL)
                        labeledField("Model") { monoField("model name", text: $draft.llmModel) }
                    }
                    .padding(14)
                }
            }
        }
    }

    /// D90/D91 featured prefill: seed the draft's four endpoint/model fields
    /// from the featured presets. Pure mapping (single source for the button
    /// and its unit test) — Speaches for STT, Ollama for LLM. `apply(to:)`
    /// fills the endpoints; the suggested models fall back to whatever the
    /// user already typed if a preset carries none.
    @MainActor
    static func applyRecommended(to draft: SettingsDraft) {
        EndpointPreset.speaches.apply(to: draft)
        draft.sttModel = EndpointPreset.speaches.suggestedSTTModel ?? draft.sttModel
        EndpointPreset.ollama.apply(to: draft)
        draft.llmModel = EndpointPreset.ollama.suggestedLLMModel ?? draft.llmModel
    }

    private var tryItStep: some View {
        VStack(spacing: 14) {
            kicker("STEP 4 OF 4")
            Text("Try it")
                .font(.lotusDisplay(26))
                .foregroundStyle(Color.lotusTextPrimary)
            // 9E (D86): the picker warns inline (with Settings deep links)
            // when the chosen key collides with a macOS shortcut — the static
            // F5 footnote it replaces only ever described one collision.
            HotkeyPicker()
            // D99: prompt + the real focused insertion target (replaces the
            // decorative HUDPreview — the live PillController panel now gives
            // listening feedback, so this box just proves insertion lands).
            Text("Hold \(hotkeyLabel) and speak — your words appear here.")
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
                .multilineTextAlignment(.center)
            tryItBox
            // D97/D99: inline setup hint on a servers-side miss (.empty/.failed);
            // .inserted/.tooShort/nil never show it (pure predicate, D14).
            if DictationController.shouldShowSetupHint(for: lastOutcome) {
                VStack(spacing: 8) {
                    Text("No text? Check your servers.")
                        .font(.lotusCaption)
                        .foregroundStyle(Color.lotusTextSecondary)
                    Button("Back to setup") { stepIndex = 2 }
                        .buttonStyle(LotusButtonStyle(.ghost))
                }
            }
            Spacer(minLength: 0)
        }
        // D98: focus the box as the step appears so it is first responder and
        // a synthesized Cmd-V lands. Scoped to this step's view, so it never
        // competes with the picker's own field on other steps.
        .onAppear { tryItFocused = true }
    }

    /// D98/D99: the focused, editable insertion box — a taller mono field (the
    /// `monoField` idiom as a multi-line `TextEditor`) that a live dictation
    /// self-inserts into. Focus is driven by `tryItFocused`.
    private var tryItBox: some View {
        TextEditor(text: $tryItText)
            .focused($tryItFocused)
            .font(.lotusMono(12))
            .foregroundStyle(Color.lotusTextPrimary)
            .scrollContentBackground(.hidden)
            .frame(height: 88)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.lotusControlFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
    }

    // MARK: - Progress + navigation

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
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
            case 2:
                Button("Back") { stepIndex = 1 }
                    .buttonStyle(LotusButtonStyle(.ghost))
                Spacer()
                // Setup is a skippable gate — Continue always advances. It
                // commits the drafted endpoints/models first (D90, ungated).
                Button("Continue") {
                    onSetupCommit()
                    stepIndex = 3
                }
                .buttonStyle(LotusButtonStyle(.primary))
            default:
                Button("Back") { stepIndex = 2 }
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

    private func open(_ deepLink: String) {
        guard let url = URL(string: deepLink) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Field builders (mirror SettingsForm's private idioms, D90)

    /// Label above a control.
    private func labeledField<V: View>(_ label: String, @ViewBuilder _ field: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
            field()
        }
    }

    /// A mono text field (endpoint URLs, model names — spec §3).
    private func monoField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.lotusMono(12))
            .foregroundStyle(Color.lotusTextPrimary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.lotusControlFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
    }

    /// Endpoint field + the advisory invalid-URL hint (spec §1E — saved anyway).
    @ViewBuilder
    private func endpointField(_ label: String, text: Binding<String>) -> some View {
        labeledField(label) {
            monoField("https://…", text: text)
            if !text.wrappedValue.isEmpty,
               !SettingsValidation.isValidEndpointURL(text.wrappedValue) {
                Text("Not a valid http(s) URL — saved anyway")
                    .font(.lotusCaption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
