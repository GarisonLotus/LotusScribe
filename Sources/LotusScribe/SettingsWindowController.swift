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
    @Published var cleanupLevel: CleanupLevel = .standard
    /// D53 app-category overrides (bundle ID → AppCategory rawValue),
    /// draft-buffered like every other field (4C). Garbage values ride
    /// along untouched — resolution ignores them (D53).
    @Published var appCategoryOverrides: [String: String] = [:]
    /// D60 dictionary terms, draft-buffered like every other field (5C).
    /// Array order is user-meaningful — D59 STT truncation priority.
    @Published var dictionaryTerms: [String] = []

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
        cleanupLevel = CleanupLevel.resolve(store.cleanupLevel)  // D40
        appCategoryOverrides = store.appCategoryOverrides  // D53
        dictionaryTerms = store.dictionaryTerms  // D56
    }

    /// Write the four D9 keys (empty → nil per D25 — unset keeps its
    /// meaning), the D40 cleanup level's raw value, and the D53 override
    /// dictionary (empty ⇄ absent handled by the store).
    func save() {
        store.sttEndpointURL = stored(sttEndpointURL)
        store.sttModel = stored(sttModel)
        store.llmEndpointURL = stored(llmEndpointURL)
        store.llmModel = stored(llmModel)
        store.cleanupLevel = cleanupLevel.rawValue
        store.appCategoryOverrides = appCategoryOverrides
        store.dictionaryTerms = dictionaryTerms  // D56 (empty ⇄ absent)
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

/// Bare settings pane (D21): SwiftUI SettingsForm hosted in an
/// NSHostingController-backed window, opened from the status-item menu.
/// SettingsStore remains the single backing store (spec §1E invariants).
/// Buffered-edit per D26: Save is the only write path; Cancel and the
/// titlebar close button write nothing (drafts are local, so titlebar close
/// is automatically a Cancel — there is no other write path).
/// D37/D44 amend Save only: the write-then-close step is gated on connection
/// probes of every drafted non-empty endpoint, STT then LLM
/// (see docs/phase-3-spec.md §3A/§3C).
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "SettingsWindowController")

    let draft: SettingsDraft
    let probeState = ProbeState()

    private let store: SettingsStore
    /// Injected probe seams (D14) so Save-path logic tests headlessly.
    private let runSTTProbe: (String, String) async -> ProbeResult
    private let runLLMProbe: (String, String) async -> ProbeResult
    /// D42 endpoint-change warm-up; injected so tests can count firings.
    private let fireWarmUp: () -> Void
    /// Exposed read-only so tests can await Save's async probe leg and
    /// assert R36 stale-task cancellation.
    private(set) var probeTask: Task<Void, Never>?
    private(set) var autoCloseTask: Task<Void, Never>?

    init(
        store: SettingsStore,
        sttProbe: @escaping (String, String) async -> ProbeResult = { endpoint, model in
            await ConnectionProbe().testSTT(endpoint: endpoint, model: model)
        },
        llmProbe: @escaping (String, String) async -> ProbeResult = { endpoint, model in
            await ConnectionProbe().testLLM(endpoint: endpoint, model: model)
        },
        warmUp: (() -> Void)? = nil
    ) {
        self.store = store
        draft = SettingsDraft(store: store)
        runSTTProbe = sttProbe
        runLLMProbe = llmProbe
        // Not a default parameter value — those can't reference `store`.
        fireWarmUp = warmUp ?? { Task { await CleanupService(settings: store).warmUp() } }
        super.init(window: nil)
        let window = NSWindow(contentViewController: NSHostingController(
            rootView: SettingsForm(
                draft: draft,
                probeState: probeState,
                onSave: { [weak self] in self?.save() },
                onCancel: { [weak self] in self?.cancel() },
                onTest: { [weak self] in self?.test() })))
        window.title = "LotusScribe Settings"
        // NSHostingController's fitting size collapses to 0x0 on macOS 26
        // (title-bar-only window), even with an explicit root .frame — size
        // the window directly, sharing SettingsForm's root-frame constant (R40).
        window.setContentSize(SettingsForm.contentSize)
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

    /// Save button / Return (D37/D44): probe every endpoint whose drafted URL
    /// is non-empty, STT then LLM; both empty → save+close as before (D36:
    /// clearing settings is never blocked by a guaranteed-fail test).
    func save() {
        // R36: a Save re-entered during the 2 s success flash must not
        // inherit the stale flash's auto-close (the window would vanish
        // mid-second-probe) or a stale probe task.
        probeTask?.cancel()
        probeTask = nil
        autoCloseTask?.cancel()
        autoCloseTask = nil

        let sttEndpoint = draft.sttEndpointURL
        let llmEndpoint = draft.llmEndpointURL
        guard !sttEndpoint.isEmpty || !llmEndpoint.isEmpty else {
            persist()
            window?.close()
            return
        }

        probeState.phase = .testing
        let sttModel = draft.sttModel
        let llmModel = draft.llmModel
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.probeEndpoints(
                sttEndpoint: sttEndpoint, sttModel: sttModel,
                llmEndpoint: llmEndpoint, llmModel: llmModel)
            // Mid-test close or re-entrant Save cancelled us — this leg
            // owns nothing anymore (D26/D37).
            guard !Task.isCancelled else { return }
            self.handleProbeResult(result)
        }
    }

    /// D44 sequential probes: skip empty URLs, stop at the first failure,
    /// prefix the reason with the endpoint's name so the sheet says WHICH
    /// connection failed.
    private func probeEndpoints(
        sttEndpoint: String, sttModel: String,
        llmEndpoint: String, llmModel: String
    ) async -> ProbeResult {
        if !sttEndpoint.isEmpty,
           case .failure(let reason) = await runSTTProbe(sttEndpoint, sttModel) {
            return .failure(reason: "Speech to Text: \(reason)")
        }
        if !llmEndpoint.isEmpty,
           case .failure(let reason) = await runLLMProbe(llmEndpoint, llmModel) {
            return .failure(reason: "Cleanup LLM: \(reason)")
        }
        return .success
    }

    /// Test button (D70): probe the drafted endpoints through the same
    /// seams as Save, but only publish the outcome to ProbeState — never
    /// persists, never closes, never sheets (the D38 sheet stays
    /// Save-only; the failure arm renders inline in the form). Both URLs
    /// empty → no-op.
    func test() {
        // R36: cancel stale probe/flash work, same as re-entrant Save.
        probeTask?.cancel()
        probeTask = nil
        autoCloseTask?.cancel()
        autoCloseTask = nil

        let sttEndpoint = draft.sttEndpointURL
        let llmEndpoint = draft.llmEndpointURL
        guard !sttEndpoint.isEmpty || !llmEndpoint.isEmpty else { return }

        probeState.phase = .testing
        let sttModel = draft.sttModel
        let llmModel = draft.llmModel
        probeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.probeEndpoints(
                sttEndpoint: sttEndpoint, sttModel: sttModel,
                llmEndpoint: llmEndpoint, llmModel: llmModel)
            guard !Task.isCancelled else { return }
            switch result {
            case .success:
                self.probeState.phase = .success
            case .failure(let reason):
                self.probeState.phase = .failure(reason)
            }
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
            persist()
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

    /// The single store-write path (D37: probe-success and Save Anyway both
    /// land here). D42 endpoint-change trigger: warm-up fires when the save
    /// changed llmEndpointURL/llmModel and cleanup is effective-enabled
    /// after the write; fire-and-forget — never blocks Save or close.
    private func persist() {
        let llmBefore = (store.llmEndpointURL, store.llmModel)
        draft.save()
        let llmAfter = (store.llmEndpointURL, store.llmModel)
        if llmAfter != llmBefore, CleanupService(settings: store).isEnabled {
            fireWarmUp()
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
                self.persist()
                self.window?.close()
            } else {
                self.probeState.phase = .idle  // back to editing, drafts intact
            }
        }
    }
}
