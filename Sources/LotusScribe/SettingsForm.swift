import AppKit
import SwiftUI

/// Settings pane, reskinned to the "Lotus Bloom" system (DESIGN_SPEC.md §5).
/// Behavior is unchanged from the grouped-Form original: text fields and the
/// pickers edit local drafts only (D26); Save/Cancel/Test come from the
/// controller; invalid URLs are saved anyway (advisory hint). This file only
/// changes presentation — cards, section headers, capsule controls, mono
/// technical values — not the settings logic.
struct SettingsForm: View {
    /// Single source for the fixed settings window content size (R40): the
    /// controller's setContentSize must agree with this root frame.
    static let contentSize = CGSize(width: 560, height: 660)

    @ObservedObject var draft: SettingsDraft
    @ObservedObject var probeState: ProbeState
    let onSave: () -> Void
    let onCancel: () -> Void
    let onTest: () -> Void

    /// Local buffer for the Dictionary add row (5C) — committed to the draft
    /// array only by the Add button.
    @State private var newTerm = ""

    /// Appearance preference mirror (Task 1). Seeded from the stored value;
    /// changing it persists + re-applies via LotusAppearance.
    @State private var appearance = LotusAppearance.mode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                sttCard
                cleanupCard
                appCategoriesCard
                dictionaryCard
                hotkeyCard
                appearanceCard
            }
            .padding(22)
        }
        .frame(width: Self.contentSize.width, height: Self.contentSize.height)
        .lotusWindowBackground()
        .disabled(probeState.phase == .testing)
        // Footer rides a bottom safe-area inset so the scroll content never
        // draws under the buttons (same reason as the original grouped Form).
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        // D37: Esc must still cancel mid-test while the buttons are disabled.
        .onExitCommand(perform: onCancel)
    }

    // MARK: Brand header

    private var header: some View {
        HStack(spacing: 10) {
            LotusMark(size: 26)
            Text("LotusScribe")
                .font(.lotusDisplay(20))
                .tracking(1.2)  // +6% wordmark tracking (spec §1)
                .foregroundStyle(Color.lotusTextPrimary)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    // MARK: Speech to Text (unchanged behavior)

    private var sttCard: some View {
        LotusCard {
            cardHeader("Speech to Text")
            cardRow {
                HStack {
                    // 7A/D69: stateless apply — fills only the preset's non-nil
                    // URLs on the draft (D26); model fields never touched.
                    Menu("Apply Preset…") {
                        ForEach(EndpointPreset.all, id: \.name) { preset in
                            Button(preset.name) { preset.apply(to: draft) }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .foregroundStyle(Color.lotusAccentText)
                    Spacer()
                }
            }
            cardRow { endpointField("Endpoint URL", text: $draft.sttEndpointURL) }
            cardRow(divider: false) {
                labeledField("Model") { monoField("model name", text: $draft.sttModel) }
            }
        }
    }

    // MARK: Cleanup LLM (unchanged behavior)

    private var cleanupCard: some View {
        LotusCard {
            cardHeader("Cleanup LLM")
            cardRow { endpointField("Endpoint URL", text: $draft.llmEndpointURL) }
            cardRow {
                labeledField("Model") { monoField("model name", text: $draft.llmModel) }
            }
            cardRow {
                VStack(alignment: .leading, spacing: 6) {
                    // 8A/D72: ON (default) → requests carry reasoning_effort
                    // "none"; OFF → field omitted (model default behavior).
                    Toggle("Suppress model reasoning", isOn: $draft.suppressModelReasoning)
                        .toggleStyle(LotusToggleStyle())
                    Text("Model behavior varies — some models 'think' before replying (slower) or follow cleanup instructions loosely. Qwen3.6 is recommended.")
                        .font(.lotusCaption)
                        .foregroundStyle(Color.lotusTextTertiary)
                }
            }
            // D40 levels. A non-empty URL is still probed on Save while Off (D44).
            cardRow(divider: false) {
                HStack {
                    Text("Cleanup")
                        .font(.lotusBody)
                        .foregroundStyle(Color.lotusTextSecondary)
                    Spacer()
                    Picker("", selection: $draft.cleanupLevel) {
                        ForEach(CleanupLevel.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .tint(Color.lotusAccentText)
                }
            }
        }
    }

    // MARK: App Categories (unchanged behavior — 4C/D54)

    private var appCategoriesCard: some View {
        LotusCard {
            cardHeader("App Categories")
            ForEach(draft.appCategoryOverrides.keys.sorted(), id: \.self) { bundleID in
                cardRow { overrideRow(bundleID: bundleID) }
            }
            cardRow(divider: false) {
                HStack {
                    addAppMenu
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .foregroundStyle(Color.lotusAccentText)
                    Spacer()
                }
            }
        }
    }

    // MARK: Dictionary (unchanged behavior — 5C/D60)

    private var dictionaryCard: some View {
        LotusCard {
            cardHeader("Dictionary")
            ForEach(draft.dictionaryTerms, id: \.self) { term in
                cardRow { termRow(term) }
            }
            cardRow(divider: false) {
                HStack(spacing: 8) {
                    monoField("Add term…", text: $newTerm)
                    Button("Add", action: addTerm)
                        .buttonStyle(LotusButtonStyle(.ghost))
                }
            }
        }
    }

    // MARK: Dictation Hotkey (Phase 9 — live write-through, like Appearance)

    private var hotkeyCard: some View {
        LotusCard {
            cardHeader("Dictation Hotkey")
            cardRow(divider: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HotkeyPicker()
                    Text("Hold to talk. Changes apply immediately.")
                        .font(.lotusCaption)
                        .foregroundStyle(Color.lotusTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Appearance (Task 1 — the one new setting)

    private var appearanceCard: some View {
        LotusCard {
            cardHeader("Appearance")
            cardRow(divider: false) {
                HStack {
                    Text("Theme")
                        .font(.lotusBody)
                        .foregroundStyle(Color.lotusTextSecondary)
                    Spacer()
                    Picker("", selection: $appearance) {
                        ForEach(LotusAppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .tint(Color.lotusAccentText)
                    // Defer the NSApp.appearance swap one runloop tick: applying
                    // it synchronously here, while the menu Picker is still
                    // dismissing, blanks the control until the next re-layout.
                    .onChange(of: appearance) { _, mode in
                        DispatchQueue.main.async { LotusAppearance.set(mode) }
                    }
                }
            }
        }
    }

    // MARK: Footer (unchanged behavior)

    private var footer: some View {
        HStack {
            probeIndicator
            Spacer()
            // 7A/D70: probe-only — never persists, closes, or sheets.
            Button("Test", action: onTest)
                .buttonStyle(LotusButtonStyle(.ghost))
            Button("Cancel", action: onCancel)
                .buttonStyle(LotusButtonStyle(.ghost))
                .keyboardShortcut(.cancelAction)
            Button("Save", action: onSave)
                .buttonStyle(LotusButtonStyle(.primary))
                .keyboardShortcut(.defaultAction)
        }
        .disabled(probeState.phase == .testing)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    /// Spinner while testing, checkmark on success (D37), inline warning +
    /// reason on failure (7A/D70). Thin UI — verified HUMAN-AT-SCREEN.
    @ViewBuilder
    private var probeIndicator: some View {
        switch probeState.phase {
        case .testing:
            ProgressView().controlSize(.small)
            Text("Testing connection…")
                .font(.lotusCaption)
                .foregroundStyle(Color.lotusTextSecondary)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.lotusAccentText)
            Text("Connected")
                .font(.lotusCaption)
                .foregroundStyle(Color.lotusTextSecondary)
        case .failure(let reason):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(reason)
                .font(.lotusCaption)
                .foregroundStyle(Color.lotusTextSecondary)
                .lineLimit(2)
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Row primitives

    private func cardHeader(_ title: String) -> some View {
        LotusSectionHeader(title)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .padding(.horizontal, 14)
    }

    /// A card row: 14pt horizontal / 11pt vertical padding, optional divider
    /// below (spec §4 row metrics).
    private func cardRow<V: View>(divider: Bool = true, @ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 0) {
            content()
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            if divider {
                Rectangle()
                    .fill(Color.lotusDivider)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
        }
    }

    /// Label above a control (used for full-width fields).
    private func labeledField<V: View>(_ label: String, @ViewBuilder _ field: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
            field()
        }
    }

    /// A mono text field (endpoint URLs, model names, bundle IDs — spec §3).
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

    // MARK: 4C — App Categories overrides (D53/D54)

    /// One override row: bundle-ID text (mono), category picker over
    /// displayNames, remove. Behavior identical to the original.
    private func overrideRow(bundleID: String) -> some View {
        HStack {
            Text(bundleID)
                .font(.lotusMono(12))
                .foregroundStyle(Color.lotusTextPrimary)
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
            .tint(Color.lotusAccentText)
            Button {
                draft.appCategoryOverrides.removeValue(forKey: bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.lotusTextTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(bundleID)")
        }
    }

    /// D54: running `.regular` apps are the picker. Selecting seeds the row
    /// with the built-in map's answer for that bundle ID.
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

    /// Picker binding for one override. Get mirrors D53 resolution (set-only
    /// write), identical to the original.
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

    private func termRow(_ term: String) -> some View {
        HStack {
            Text(term)
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                draft.dictionaryTerms.removeAll { $0 == term }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.lotusTextTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(term)")
        }
    }

    /// D60 add guard (unchanged): trim; no-op on empty or case-insensitive
    /// duplicate; append (lowest D59 priority) and clear the field.
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
