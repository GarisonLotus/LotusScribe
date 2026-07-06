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
    static let contentSize = CGSize(width: 420, height: 740)  // 7A: +40 for presets row

    @ObservedObject var draft: SettingsDraft
    @ObservedObject var probeState: ProbeState
    let onSave: () -> Void
    let onCancel: () -> Void
    let onTest: () -> Void

    /// Local buffer for the Dictionary add row (5C) — committed to the
    /// draft array only by the Add button.
    @State private var newTerm = ""

    var body: some View {
        Form {
            Section("Speech to Text") {
                // 7A/D69: stateless apply — fills only the preset's non-nil
                // URLs on the draft (D26); model fields never touched.
                Menu("Apply Preset…") {
                    ForEach(EndpointPreset.all, id: \.name) { preset in
                        Button(preset.name) { preset.apply(to: draft) }
                    }
                }
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
            // 5C/D60: user dictionary, draft-buffered (D26). Rows stay in
            // list order — order IS the D59 STT truncation priority.
            Section("Dictionary") {
                ForEach(draft.dictionaryTerms, id: \.self) { term in
                    termRow(term)
                }
                HStack {
                    TextField("Add term…", text: $newTerm)
                    Button("Add", action: addTerm)
                }
            }
        }
        .formStyle(.grouped)
        .disabled(probeState.phase == .testing)
        // Button row rides a bottom safe-area inset (not a VStack sibling):
        // on macOS 26 the grouped Form's scroll content drew underneath a
        // sibling row (Save/Cancel floated over the last list row). The
        // inset makes the scroll view keep its content clear of the
        // buttons, and .bar gives the row an opaque backdrop.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                probeIndicator
                Spacer()
                // 7A/D70: probe-only — never persists, closes, or sheets.
                Button("Test", action: onTest)
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .disabled(probeState.phase == .testing)
            .padding()
            .background(.bar)
        }
        // D37: Esc must still cancel mid-test while the buttons are disabled
        // — key equivalents skip disabled buttons, so cancelOperation lands
        // here instead.
        .onExitCommand(perform: onCancel)
        // Both dimensions fixed: on macOS 26 the NSHostingController fitting
        // size collapses to 0x0 for a grouped Form (width-only .frame didn't
        // take either), leaving a title-bar-only window. 740 pt fits the
        // presets row, four fields, the cleanup picker, the App Categories and Dictionary
        // sections (~4 rows each before the grouped Form scrolls), section
        // headers, hint rows, and the button row. Shared with the
        // controller's setContentSize (R40).
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
    }

    /// Spinner while testing, green checkmark on success (D37), inline
    /// warning + reason on failure (7A/D70 — the Test button has no sheet;
    /// Save's failure sheet still precedes this, and its Try Again resets
    /// `.idle`). Thin UI — verified HUMAN-AT-SCREEN, not unit-tested.
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
        case .failure(let reason):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.caption)
                .lineLimit(2)
        case .idle:
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

    // MARK: 5C — Dictionary (D60)

    /// One term row: term text + remove, same row vocabulary as the App
    /// Categories rows above.
    private func termRow(_ term: String) -> some View {
        HStack {
            Text(term)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                draft.dictionaryTerms.removeAll { $0 == term }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(term)")
        }
    }

    /// D60 add guard (mirrors 4C's duplicate-add): trim; no-op on empty or
    /// case-insensitive duplicate; append (end of list = lowest D59
    /// priority) and clear the field.
    private func addTerm() {
        let term = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              !draft.dictionaryTerms.contains(where: {
                  $0.caseInsensitiveCompare(term) == .orderedSame
              })
        else { return }
        draft.dictionaryTerms.append(term)
        newTerm = ""
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
