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

/// Bare settings pane (D21): SwiftUI `Form` hosted in an NSHostingController-backed
/// window, opened from the status-item menu. Touches only the four D9 keys;
/// SettingsStore remains the single backing store (spec §1E invariants).
final class SettingsWindowController: NSWindowController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "SettingsWindowController")

    convenience init(store: SettingsStore) {
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsForm(store: store)))
        window.title = "LotusScribe Settings"
        // NSHostingController's fitting size collapses to 0x0 on macOS 26
        // (title-bar-only window), even with an explicit root .frame — size
        // the window directly. Must match SettingsForm's root frame.
        window.setContentSize(NSSize(width: 420, height: 300))
        self.init(window: window)
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
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        Self.logger.info(
            "post-show: window=\(self.window != nil ? "non-nil" : "nil", privacy: .public) isVisible=\(self.window?.isVisible ?? false, privacy: .public) frame=\(String(describing: self.window?.frame), privacy: .public)")
    }
}

/// Four text fields write through to SettingsStore on every change; empty
/// fields store nil so "unset" keeps its meaning (defaults come from code paths
/// that read nil). Invalid URLs are saved anyway — the hint is advisory.
private struct SettingsForm: View {
    let store: SettingsStore

    @State private var sttEndpointURL: String
    @State private var sttModel: String
    @State private var llmEndpointURL: String
    @State private var llmModel: String

    init(store: SettingsStore) {
        self.store = store
        _sttEndpointURL = State(initialValue: store.sttEndpointURL ?? "")
        _sttModel = State(initialValue: store.sttModel ?? "")
        _llmEndpointURL = State(initialValue: store.llmEndpointURL ?? "")
        _llmModel = State(initialValue: store.llmModel ?? "")
    }

    var body: some View {
        Form {
            Section("Speech to Text") {
                endpointField("Endpoint URL", text: $sttEndpointURL)
                TextField("Model", text: $sttModel)
            }
            Section("Cleanup LLM") {
                endpointField("Endpoint URL", text: $llmEndpointURL)
                TextField("Model", text: $llmModel)
            }
        }
        .formStyle(.grouped)
        // Both dimensions fixed: on macOS 26 the NSHostingController fitting
        // size collapses to 0x0 for a grouped Form (width-only .frame didn't
        // take either), leaving a title-bar-only window. 300 pt fits the four
        // fields, two section headers, and hint rows.
        .frame(width: 420, height: 300)
        .onChange(of: sttEndpointURL) { store.sttEndpointURL = stored(sttEndpointURL) }
        .onChange(of: sttModel) { store.sttModel = stored(sttModel) }
        .onChange(of: llmEndpointURL) { store.llmEndpointURL = stored(llmEndpointURL) }
        .onChange(of: llmModel) { store.llmModel = stored(llmModel) }
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

    private func stored(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
