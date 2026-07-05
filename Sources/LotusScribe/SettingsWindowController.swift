import AppKit
import os
import SwiftUI

/// Pure validation for the settings pane's URL hint. See docs/phase-1-spec.md §1E.
enum SettingsValidation {
    /// True when `string` parses with an http/https scheme and a non-empty host.
    /// Hint-only: callers must still save invalid values (spec §1E).
    static func isValidEndpointURL(_ string: String) -> Bool {
        guard let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty
        else { return false }
        return true
    }
}

/// Buffered drafts for the settings pane (D26): fields edit these; `save()`
/// is the only path that writes to SettingsStore (empty → nil per D25).
@MainActor
final class SettingsDraft: ObservableObject {
    @Published var sttEndpointURL = ""
    @Published var sttModel = ""
    @Published var llmEndpointURL = ""
    @Published var llmModel = ""

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        reload()
    }

    /// Re-seed drafts from the store. Called on every `show()` so reopening
    /// discards abandoned edits.
    func reload() {
        sttEndpointURL = store.sttEndpointURL ?? ""
        sttModel = store.sttModel ?? ""
        llmEndpointURL = store.llmEndpointURL ?? ""
        llmModel = store.llmModel ?? ""
    }

    /// Write all four D9 keys; empty → nil per D25 (unset keeps its meaning).
    func save() {
        store.sttEndpointURL = stored(sttEndpointURL)
        store.sttModel = stored(sttModel)
        store.llmEndpointURL = stored(llmEndpointURL)
        store.llmModel = stored(llmModel)
    }

    private func stored(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}

/// Bare settings pane (D21): SwiftUI `Form` hosted in an NSHostingController-backed
/// window, opened from the status-item menu. Touches only the four D9 keys;
/// SettingsStore remains the single backing store (spec §1E invariants).
/// Buffered-edit per D26: Save is the only write path; Cancel and the
/// titlebar close button write nothing (drafts are local, so titlebar close
/// is automatically a Cancel — there is no other write path).
final class SettingsWindowController: NSWindowController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "SettingsWindowController")

    let draft: SettingsDraft

    init(store: SettingsStore) {
        draft = SettingsDraft(store: store)
        super.init(window: nil)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsForm(
                draft: draft,
                onSave: { [weak self] in self?.save() },
                onCancel: { [weak self] in self?.cancel() })))
        window.title = "LotusScribe Settings"
        // NSHostingController's fitting size collapses to 0x0 on macOS 26
        // (title-bar-only window), even with an explicit root .frame — size
        // the window directly. Must match SettingsForm's root frame.
        window.setContentSize(NSSize(width: 420, height: 350))
        self.window = window
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Parameterless form must be spelled out: with only a defaulted
    /// `init(store:)`, `SettingsWindowController()` resolves to the inherited
    /// `NSWindowController.init()` (window: nil) and `show()` silently no-ops.
    convenience init() {
        self.init(store: SettingsStore())
    }

    /// LSUIElement apps aren't active when a menu item fires — activate first
    /// or the window appears behind the frontmost app without key focus.
    func show() {
        Self.logger.info("show() entered")
        // StatusItemController caches this controller, so the window (and its
        // hosting root) survives close. Re-seed the drafts instead of
        // rebuilding the contentViewController — @Published refreshes the
        // cached form's fields in place (D26 reopen behavior, minimal path).
        draft.reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        Self.logger.info(
            "post-show: window=\(self.window != nil ? "non-nil" : "nil", privacy: .public) isVisible=\(self.window?.isVisible ?? false, privacy: .public) frame=\(String(describing: self.window?.frame), privacy: .public)")
    }

    /// Save button / Return: persist all four keys, then close (D26).
    func save() {
        draft.save()
        window?.close()
    }

    /// Cancel button / Esc: close without writing (D26).
    func cancel() {
        window?.close()
    }
}

/// Four text fields edit local drafts only (D26) — no store writes while
/// typing. Save/Cancel actions come from the controller. Invalid URLs are
/// saved anyway — the hint is advisory and runs live on the drafts.
private struct SettingsForm: View {
    @ObservedObject var draft: SettingsDraft
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
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom])
        }
        // Both dimensions fixed: on macOS 26 the NSHostingController fitting
        // size collapses to 0x0 for a grouped Form (width-only .frame didn't
        // take either), leaving a title-bar-only window. 350 pt fits the four
        // fields, two section headers, hint rows, and the button row.
        .frame(width: 420, height: 350)
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
