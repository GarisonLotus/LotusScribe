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
            case .blocked:
                // D64: first pill text label — a bare lock glyph is
                // unlearnable; orange = environmental warning (red stays
                // transcription-failure-only, D43).
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Can't dictate here")
                        .font(.callout)
                }
            case .stagedSuccess(let stage):
                // D48: slot 1 = STT proof (same check as .success),
                // slot 2 = cleanup stage.
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    cleanupSlot(stage)
                }
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

    /// Second slot of the staged display (D48): pending reuses the
    /// `.processing` spinner vocabulary; missed is amber-triangle warning,
    /// distinct from `.error`'s red circle.
    @ViewBuilder
    private func cleanupSlot(_ stage: CleanupStage) -> some View {
        switch stage {
        case .pending:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .missed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        }
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
    /// Raw RMS goes through the perceptual dBFS map here, at render
    /// time — stored levels stay raw per the D32 contract.
    private func barHeight(_ level: Float) -> CGFloat {
        // The 24 pt interior inset is view-local; its numeric match with
        // PillMetrics.bottomMargin is coincidental, not shared (R32).
        let maxHeight = PillMetrics.contentSize.height - 24
        let display = CGFloat(AudioLevel.display(rms: level))
        return 4 + display * (maxHeight - 4)
    }
}
