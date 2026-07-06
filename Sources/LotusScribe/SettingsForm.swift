import AppKit
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
    static let contentSize = CGSize(width: 420, height: 560)  // 4C: +170 for App Categories

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
                // 4C/D54: per-app tone overrides, draft-buffered like every
                // other field (D26) — rows edit the draft dict only.
                Section("App Categories") {
                    ForEach(draft.appCategoryOverrides.keys.sorted(), id: \.self) { bundleID in
                        overrideRow(bundleID: bundleID)
                    }
                    addAppMenu
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
        // take either), leaving a title-bar-only window. 560 pt fits the four
        // fields, the cleanup picker, the App Categories section (~4 rows
        // before the grouped Form scrolls), section headers, hint rows, and
        // the button row. Shared with the controller's setContentSize (R40).
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

    // MARK: 4C — App Categories overrides (D53/D54)

    /// One override row: bundle-ID text (spec: app-name resolution not
    /// required this phase), category picker over displayNames, remove.
    private func overrideRow(bundleID: String) -> some View {
        HStack {
            Text(bundleID)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Picker("", selection: categoryBinding(for: bundleID)) {
                ForEach(AppCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .labelsHidden()
            .fixedSize()
            Button {
                draft.appCategoryOverrides.removeValue(forKey: bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(bundleID)")
        }
    }

    /// D54: running `.regular` apps are the picker — the app you want to
    /// override is almost always running. Selecting seeds the row with the
    /// built-in map's answer for that bundle ID.
    private var addAppMenu: some View {
        Menu("Add App…") {
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { app -> (name: String, bundleID: String)? in
                    guard let id = app.bundleIdentifier else { return nil }
                    return (app.localizedName ?? id, id)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            ForEach(apps, id: \.bundleID) { app in
                Button("\(app.name) — \(app.bundleID)") {
                    // Re-adding an existing row must not clobber its edit.
                    guard draft.appCategoryOverrides[app.bundleID] == nil else { return }
                    draft.appCategoryOverrides[app.bundleID] =
                        AppCategory.category(forBundleID: app.bundleID, overrides: [:]).rawValue
                }
            }
        }
    }

    /// Picker binding for one override. Get mirrors D53 resolution, so a
    /// garbage stored value DISPLAYS as the built-in fallback but rides
    /// along untouched unless the user actually picks (set-only write).
    private func categoryBinding(for bundleID: String) -> Binding<AppCategory> {
        Binding(
            get: {
                AppCategory.category(
                    forBundleID: bundleID, overrides: draft.appCategoryOverrides)
            },
            set: { draft.appCategoryOverrides[bundleID] = $0.rawValue }
        )
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
