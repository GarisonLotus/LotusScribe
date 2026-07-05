import Foundation

/// Pure RMS math for the waveform pill (D32) — no TCC, 100% unit-tested
/// (D14). See docs/phase-2-spec.md §"Sub-phase 2A".
enum AudioLevel {
    /// Normalized root-mean-square of little-endian Int16 PCM samples,
    /// 0 (silence) … 1 (full scale). Empty or sub-sample input is 0; a
    /// trailing odd byte is ignored.
    static func rms(pcm16: Data) -> Float {
        let sampleCount = pcm16.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else { return 0 }

        let sumOfSquares = pcm16.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            (0..<sampleCount).reduce(into: 0.0) { sum, index in
                // loadUnaligned: Data gives no alignment guarantee.
                let sample = raw.loadUnaligned(
                    fromByteOffset: index * MemoryLayout<Int16>.size, as: Int16.self)
                let value = Double(Int16(littleEndian: sample))
                sum += value * value
            }
        }
        return Float((sumOfSquares / Double(sampleCount)).squareRoot() / Double(Int16.max))
    }

    /// Perceptual display level for the waveform bars: raw RMS → dBFS,
    /// clamped to [-50, 0] dB and mapped linearly onto 0…1. Speech RMS
    /// (~0.02–0.15 full scale) lands mid-range instead of pinning near
    /// the bar floor; exact 0 stays 0.
    static func display(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(max(1 + db / 50, 0), 1)
    }
}
