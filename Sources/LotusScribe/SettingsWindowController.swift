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

/// Probe lifecycle for the Save flow (D37), published for SettingsForm.
enum ProbePhase: Equatable {
    case idle
    case testing
    case success
    case failure(String)
}

/// Observable wrapper so the hosted form reacts to probe progress.
@MainActor
final class ProbeState: ObservableObject {
    @Published var phase: ProbePhase = .idle
}

/// Bare settings pane (D21): SwiftUI `Form` hosted in an NSHostingController-backed
/// window, opened from the status-item menu. Touches only the four D9 keys;
/// SettingsStore remains the single backing store (spec §1E invariants).
/// Buffered-edit per D26: Save is the only write path; Cancel and the
/// titlebar close button write nothing (drafts are local, so titlebar close
/// is automatically a Cancel — there is no other write path).
/// D37 amends Save only: the write-then-close step is gated on a connection
/// probe of the drafted STT endpoint (see docs/phase-3-spec.md §3A).
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "SettingsWindowController")

    let draft: SettingsDraft
    let probeState = ProbeState()

    /// Injected probe seam (D14) so Save-path logic tests headlessly.
    private let runProbe: (String, String) async -> ProbeResult
    /// Exposed read-only so tests can await Save's async probe leg.
    private(set) var probeTask: Task<Void, Never>?
    private var autoCloseTask: Task<Void, Never>?

    init(
        store: SettingsStore,
        probe: @escaping (String, String) async -> ProbeResult = { endpoint, model in
            await ConnectionProbe().testSTT(endpoint: endpoint, model: model)
        }
    ) {
        draft = SettingsDraft(store: store)
        runProbe = probe
        super.init(window: nil)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsForm(
                draft: draft,
                probeState: probeState,
                onSave: { [weak self] in self?.save() },
                onCancel: { [weak self] in self?.cancel() })))
        window.title = "LotusScribe Settings"
        // NSHostingController's fitting size collapses to 0x0 on macOS 26
        // (title-bar-only window), even with an explicit root .frame — size
        // the window directly. Must match SettingsForm's root frame.
        window.setContentSize(NSSize(width: 420, height: 350))
        window.delegate = self  // windowWillClose cancels in-flight probe work
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
        probeState.phase = .idle  // D37: reopen resets probe state
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        Self.logger.info(
            "post-show: window=\(self.window != nil ? "non-nil" : "nil", privacy: .public) isVisible=\(self.window?.isVisible ?? false, privacy: .public) frame=\(String(describing: self.window?.frame), privacy: .public)")
    }

    /// Save button / Return (D37): empty drafted STT URL → save+close as
    /// before (D36: clearing settings is never blocked by a guaranteed-fail
    /// test); otherwise gate the write-then-close on a connection probe.
    func save() {
        let endpoint = draft.sttEndpointURL
        guard !endpoint.isEmpty else {
            draft.save()
            window?.close()
            return
        }

        probeState.phase = .testing
        let model = draft.sttModel
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.runProbe(endpoint, model)
            // Mid-test close cancelled us — write nothing (D26/D37).
            guard !Task.isCancelled else { return }
            self.handleProbeResult(result)
        }
    }

    /// Cancel button / Esc: close without writing (D26).
    func cancel() {
        window?.close()
    }

    /// Every close path (Cancel, Esc, titlebar, force-close) lands here:
    /// cancel in-flight probe work so nothing is written after the window
    /// is gone (D37 mid-test close semantics).
    func windowWillClose(_ notification: Notification) {
        probeTask?.cancel()
        probeTask = nil
        autoCloseTask?.cancel()
        autoCloseTask = nil
    }

    private func handleProbeResult(_ result: ProbeResult) {
        switch result {
        case .success:
            // D37: persist immediately — a force-close during the 2 s
            // checkmark flash cannot lose the save.
            draft.save()
            probeState.phase = .success
            autoCloseTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.window?.close()
            }
        case .failure(let reason):
            probeState.phase = .failure(reason)
            presentFailureSheet(reason: reason)
        }
    }

    /// D38: this sheet is a direct response to the user's Save click in the
    /// settings window — outside the dictation loop's no-alert policy.
    private func presentFailureSheet(reason: String) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = "There's a problem with the connection."
        alert.informativeText = reason
        alert.addButton(withTitle: "Save Anyway")
        alert.addButton(withTitle: "Try Again")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            if response == .alertFirstButtonReturn {
                // D37: "close anyways" honors the Save click — persist.
                self.draft.save()
                self.window?.close()
            } else {
                self.probeState.phase = .idle  // back to editing, drafts intact
            }
        }
    }
}

/// Four text fields edit local drafts only (D26) — no store writes while
/// typing. Save/Cancel actions come from the controller. Invalid URLs are
/// saved anyway — the hint is advisory and runs live on the drafts.
private struct SettingsForm: View {
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
        // take either), leaving a title-bar-only window. 350 pt fits the four
        // fields, two section headers, hint rows, and the button row.
        .frame(width: 420, height: 350)
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
