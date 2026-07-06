import SwiftUI

/// The dictation HUD's SwiftUI content, reskinned to "Lotus Bloom"
/// (DESIGN_SPEC.md §5–6): a floating capsule whose interior tracks PillState.
/// Pure rendering — all data arrives via PillViewModel; the DictationController
/// state machine that drives it is unchanged. The eight PillStates map onto the
/// spec's three visual faces: warming/recording → Listening, processing and
/// staged-pending → Processing ("Cleaning up…"), success/staged-done →
/// Inserted; error, missed, and blocked keep their distinct affordances.
struct PillView: View {
    @ObservedObject var model: PillViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            content
                .id(caseKey)
                .transition(reduceMotion
                    ? .opacity
                    : .scale(scale: 0.96).combined(with: .opacity))
        }
        // Root frame from PillMetrics only (D31/R21) — must match
        // PillPanel.setContentSize (macOS 26 autosizing is broken, R23).
        .frame(
            width: PillMetrics.contentSize.width,
            height: PillMetrics.contentSize.height)
        .background(Color.lotusHUDFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
        // Spec §6: state swaps crossfade / appear spring; nothing under Reduce
        // Motion.
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
            value: model.state)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .hidden:
            EmptyView()
        case .warming:
            // D29: engine not live yet — dimmed static bars, "hold on".
            listening(dimmed: true)
        case .recording:
            listening(dimmed: false)
        case .processing:
            processing(showCheck: false)
        case .stagedSuccess(.pending):
            // D48 slot 1 = STT proof; cleanup still running.
            processing(showCheck: true)
        case .success, .stagedSuccess(.done):
            inserted(missed: false)
        case .stagedSuccess(.missed):
            // D47: cleanup missed — raw transcript inserted, amber distinction.
            inserted(missed: true)
        case .error:
            terminal(system: "exclamationmark.circle.fill",
                     tint: .red, text: "Couldn't transcribe")
        case .blocked:
            // D64: secure-input blocked — orange, learnable text label.
            terminal(system: "lock.fill", tint: .orange, text: "Can't dictate here")
        }
    }

    /// Distinct identity per visual face so transitions fire on real changes.
    private var caseKey: Int {
        switch model.state {
        case .hidden: return 0
        case .warming: return 1
        case .recording: return 2
        case .processing, .stagedSuccess(.pending): return 3
        case .success, .stagedSuccess(.done): return 4
        case .stagedSuccess(.missed): return 5
        case .error: return 6
        case .blocked: return 7
        }
    }

    // MARK: - Listening (spec §5)

    private func listening(dimmed: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.lotusAccentPink)
                .frame(width: 7, height: 7)
                .opacity(dimmed ? 0.4 : 1)
            waveform(dimmed: dimmed)
            Text("LISTENING")
                .font(.lotusMono(11))
                .tracking(1.2)
                .foregroundStyle(Color.lotusTextPrimary)
            hotkeyChip
        }
        .padding(.horizontal, 16)
    }

    private var hotkeyChip: some View {
        Text("fn")
            .font(.lotusMono(11))
            .foregroundStyle(Color.lotusTextSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.lotusControlFill, in: Capsule())
    }

    /// 12 gradient bars. Dimmed (warming) draws a flat low row; recording
    /// drives heights from the live levels, animating each bar over 90ms
    /// (spec §6). Reduce Motion drops the per-bar animation.
    private func waveform(dimmed: Bool) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<PillMetrics.barCount, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient.lotusAccent)
                    .frame(width: 3, height: barHeight(at: index, dimmed: dimmed))
            }
        }
        .frame(height: 24)
        .opacity(dimmed ? 0.35 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: model.levels)
    }

    /// Levels left-padded with silence so the waveform fills from the right as
    /// data arrives (unchanged from the original).
    private var paddedLevels: [Float] {
        let missing = PillMetrics.barCount - model.levels.count
        guard missing > 0 else { return model.levels }
        return Array(repeating: 0, count: missing) + model.levels
    }

    /// 4pt floor up to a 24pt cap. Raw RMS → perceptual dBFS at render time
    /// (D32 contract keeps stored levels raw).
    private func barHeight(at index: Int, dimmed: Bool) -> CGFloat {
        guard !dimmed else { return 4 }
        let level = paddedLevels[index]
        let display = CGFloat(AudioLevel.display(rms: level))
        return 4 + display * 20
    }

    // MARK: - Processing (spec §5)

    private func processing(showCheck: Bool) -> some View {
        HStack(spacing: 10) {
            if showCheck {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(LinearGradient.lotusAccent)
            }
            PulsingDots(reduceMotion: reduceMotion)
            Text("Cleaning up…")
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextPrimary)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Inserted (spec §5)

    private func inserted(missed: Bool) -> some View {
        HStack(spacing: 10) {
            if missed {
                // D47: amber triangle preserves the raw-fallback distinction.
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(LinearGradient.lotusAccent)
            }
            Text(missed ? "Inserted (raw)" : "Inserted")
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextPrimary)
        }
        .padding(.horizontal, 16)
    }

    private func terminal(system: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: system)
                .font(.system(size: 18))
                .foregroundStyle(tint)
            Text(text)
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextPrimary)
        }
        .padding(.horizontal, 16)
    }
}

/// Three dots pulsing opacity 1 → .55 → .25 on a 900ms loop (spec §6). Static
/// under Reduce Motion.
private struct PulsingDots: View {
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            dots { _ in 0.7 }
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                dots { i in
                    // 900ms loop, staggered per dot.
                    let phase = (t / 0.9 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                    return 0.25 + 0.75 * (0.5 + 0.5 * cos(phase * 2 * .pi))
                }
            }
        }
    }

    private func dots(_ opacity: @escaping (Int) -> Double) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.lotusAccentText)
                    .frame(width: 5, height: 5)
                    .opacity(opacity(i))
            }
        }
    }
}
