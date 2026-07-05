import SwiftUI

/// The pill's SwiftUI content: a translucent capsule whose interior tracks
/// PillState (spec §2B). Pure rendering — all data arrives via PillViewModel.
struct PillView: View {
    @ObservedObject var model: PillViewModel

    var body: some View {
        ZStack {
            switch model.state {
            case .hidden:
                EmptyView()
            case .warming:
                // D29: static dimmed bars = "engine not live yet, hold on".
                bars(Array(repeating: 0, count: PillMetrics.barCount))
                    .opacity(0.35)
            case .recording:
                bars(paddedLevels)
            case .processing:
                ProgressView()
                    .controlSize(.small)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            }
        }
        // Root frame from PillMetrics only (D31/R21). Both dimensions fixed:
        // must match PillPanel.setContentSize — macOS 26 fitting-size
        // autosizing is broken for hosted SwiftUI (R23).
        .frame(
            width: PillMetrics.contentSize.width,
            height: PillMetrics.contentSize.height)
        .background(.ultraThinMaterial, in: Capsule())
    }

    /// Levels left-padded with silence so the waveform fills in from the
    /// right as data arrives, instead of jumping around while short.
    private var paddedLevels: [Float] {
        let missing = PillMetrics.barCount - model.levels.count
        guard missing > 0 else { return model.levels }
        return Array(repeating: 0, count: missing) + model.levels
    }

    private func bars(_ levels: [Float]) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.primary.opacity(0.8))
                    .frame(width: 3, height: barHeight(levels[index]))
            }
        }
    }

    /// 4 pt floor (silence stays visible) up to the capsule interior.
    private func barHeight(_ level: Float) -> CGFloat {
        let maxHeight = PillMetrics.contentSize.height - 24
        let clamped = CGFloat(min(max(level, 0), 1))
        return 4 + clamped * (maxHeight - 4)
    }
}
