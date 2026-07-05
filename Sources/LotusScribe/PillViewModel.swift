import SwiftUI

/// View data for PillView: current state + the rolling window of waveform
/// levels. Holds no dictation state of its own (spec §2B invariant).
@MainActor
final class PillViewModel: ObservableObject {
    @Published var state: PillState = .hidden
    @Published var levels: [Float] = []

    /// Append one RMS level (0…1), trimming to the newest `barCount` values —
    /// oldest dropped first, order preserved.
    func push(level: Float) {
        levels.append(level)
        if levels.count > PillMetrics.barCount {
            levels.removeFirst(levels.count - PillMetrics.barCount)
        }
    }
}
