import AppKit
import SwiftUI

/// Owns the pill panel, its hosting view, and the view model. This is the
/// only surface 2C calls: show / update / push(level:) / hide (spec §2B).
/// Touches no TCC-bearing API. Unreachable from app code until 2C wires it.
@MainActor
final class PillController {
    // Internal (not private) so tests can assert panel behavior (R23/R24).
    let panel: PillPanel
    private let model = PillViewModel()
    private var flashWork: DispatchWorkItem?

    init() {
        panel = PillPanel()
        panel.contentView = NSHostingView(
            rootView: PillView(model: model).ignoresSafeArea())
        // R23: re-assert the D31 size after the hosting view lands —
        // contentView assignment must not renegotiate it.
        panel.setContentSize(PillMetrics.contentSize)
    }

    /// Current display state (read-only for callers and tests).
    var state: PillState { model.state }

    /// Position bottom-center on the main screen and order front without
    /// activating, then apply `state`.
    func show(_ state: PillState) {
        update(state)
        panel.positionBottomCenter(on: NSScreen.main)
        panel.orderFrontRegardless()
    }

    /// Switch state in place. `.success`/`.error` auto-hide after
    /// `flashDuration` (D31); any newer update cancels a pending flash.
    func update(_ state: PillState) {
        flashWork?.cancel()
        flashWork = nil
        model.state = state
        guard state == .success || state == .error else { return }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        flashWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + PillMetrics.flashDuration, execute: work)
    }

    /// Feed one waveform level (AudioRecorder.onLevel → here in 2C).
    func push(level: Float) {
        model.push(level: level)
    }

    /// Order out and reset view data so the next show starts clean.
    func hide() {
        flashWork?.cancel()
        flashWork = nil
        model.state = .hidden
        model.levels = []
        panel.orderOut(nil)
    }
}
