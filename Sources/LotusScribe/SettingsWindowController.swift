import AppKit
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
    convenience init(store: SettingsStore = SettingsStore()) {
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsForm(store: store)))
        window.title = "LotusScribe Settings"
        self.init(window: window)
    }

    /// LSUIElement apps aren't active when a menu item fires — activate first
    /// or the window appears behind the frontmost app without key focus.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
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
        .frame(width: 420)
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
