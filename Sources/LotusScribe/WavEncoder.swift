import Foundation

/// Pure RIFF/WAVE encoder (D17: resampling happens upstream in
/// AudioRecorder; this only frames already-converted PCM16 samples).
/// See docs/phase-1-spec.md §"Sub-phase 1B".
enum WavEncoder {
    /// Wraps little-endian 16-bit PCM samples in a canonical 44-byte
    /// RIFF/fmt/data header. `pcm16` may be empty (valid zero-length WAV).
    static func wavData(pcm16: Data, sampleRate: Int, channels: Int) -> Data {
        let bitsPerSample = 16
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = sampleRate * blockAlign

        var wav = Data(capacity: 44 + pcm16.count)
        wav.append(contentsOf: Array("RIFF".utf8))
        appendLE(UInt32(36 + pcm16.count), to: &wav)  // file size minus RIFF/size fields
        wav.append(contentsOf: Array("WAVE".utf8))

        wav.append(contentsOf: Array("fmt ".utf8))
        appendLE(UInt32(16), to: &wav)  // fmt chunk size for plain PCM
        appendLE(UInt16(1), to: &wav)  // audio format 1 = linear PCM
        appendLE(UInt16(channels), to: &wav)
        appendLE(UInt32(sampleRate), to: &wav)
        appendLE(UInt32(byteRate), to: &wav)
        appendLE(UInt16(blockAlign), to: &wav)
        appendLE(UInt16(bitsPerSample), to: &wav)

        wav.append(contentsOf: Array("data".utf8))
        appendLE(UInt32(pcm16.count), to: &wav)
        wav.append(pcm16)
        return wav
    }

    private static func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}
