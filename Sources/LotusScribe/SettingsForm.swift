import SwiftUI

/// Settings pane form, extracted from SettingsWindowController per R37.
/// Text fields and the cleanup-level picker edit local drafts only (D26) —
/// no store writes while typing; Save/Cancel actions come from the
/// controller. Invalid URLs are saved anyway — the hint is advisory and
/// runs live on the drafts.
struct SettingsForm: View {
    /// Single source for the fixed settings window content size (R40):
    /// the macOS 26 fitting-size collapse forces both this form's root
    /// frame and the controller's setContentSize to agree.
    static let contentSize = CGSize(width: 420, height: 390)

    @ObservedObject var draft: SettingsDraft
    @ObservedObject var probeState: ProbeState
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Speech to Text") {
                    endpointField("Endpoint URL", text: $draft.sttEndpointURL)
                    TextField("Model", text: $draft.sttModel)
                }
                Section("Cleanup LLM") {
                    endpointField("Endpoint URL", text: $draft.llmEndpointURL)
                    TextField("Model", text: $draft.llmModel)
                    // D40 levels. A non-empty URL is still probed on Save
                    // while Off (D44 — the URL outlives the level).
                    Picker("Cleanup", selection: $draft.cleanupLevel) {
                        ForEach(CleanupLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .disabled(probeState.phase == .testing)
            HStack {
                probeIndicator
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(probeState.phase == .testing)
            .padding([.horizontal, .bottom])
        }
        // D37: Esc must still cancel mid-test while the buttons are disabled
        // — key equivalents skip disabled buttons, so cancelOperation lands
        // here instead.
        .onExitCommand(perform: onCancel)
        // Both dimensions fixed: on macOS 26 the NSHostingController fitting
        // size collapses to 0x0 for a grouped Form (width-only .frame didn't
        // take either), leaving a title-bar-only window. 390 pt fits the four
        // fields, the cleanup picker, two section headers, hint rows, and the
        // button row. Shared with the controller's setContentSize (R40).
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }

    /// Spinner while testing, green checkmark on success (D37). Thin UI —
    /// verified HUMAN-AT-SCREEN, not unit-tested. Failure needs no row
    /// indicator: the sheet carries the message.
    @ViewBuilder
    private var probeIndicator: some View {
        switch probeState.phase {
        case .testing:
            ProgressView()
                .controlSize(.small)
            Text("Testing connection…")
                .font(.caption)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Connected")
                .font(.caption)
        case .idle, .failure:
            EmptyView()
        }
    }

    @ViewBuilder
    private func endpointField(_ label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
        if !text.wrappedValue.isEmpty,
           !SettingsValidation.isValidEndpointURL(text.wrappedValue) {
            Text("Not a valid http(s) URL — saved anyway")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
