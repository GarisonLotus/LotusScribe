import Foundation
import Testing
@testable import LotusScribe

/// Unit tests for the pure 1B WAV framing (spec §1B: header fields,
/// data-chunk length, total-size fields, empty input). Offsets follow the
/// canonical 44-byte RIFF/fmt/data layout.
struct WavEncoderTests {
    /// Four samples (8 bytes) of recognizable PCM.
    private static let pcm = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    private static let wav = WavEncoder.wavData(pcm16: pcm, sampleRate: 16_000, channels: 1)

    private func u16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func u32(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << (8 * $1) }
    }

    private func fourCC(_ data: Data, at offset: Int) -> String {
        String(decoding: data[offset..<offset + 4], as: UTF8.self)
    }

    @Test func chunkMarkersAreRiffWaveFmtData() {
        #expect(fourCC(Self.wav, at: 0) == "RIFF")
        #expect(fourCC(Self.wav, at: 8) == "WAVE")
        #expect(fourCC(Self.wav, at: 12) == "fmt ")
        #expect(fourCC(Self.wav, at: 36) == "data")
    }

    @Test func fmtChunkDescribesPlainPCM() {
        #expect(u32(Self.wav, at: 16) == 16)  // fmt chunk size
        #expect(u16(Self.wav, at: 20) == 1)  // audio format 1 = PCM
        #expect(u16(Self.wav, at: 34) == 16)  // bits per sample
    }

    @Test func fmtChunkCarriesRateChannelsAndDerivedFields() {
        #expect(u16(Self.wav, at: 22) == 1)  // channels
        #expect(u32(Self.wav, at: 24) == 16_000)  // sample rate
        #expect(u32(Self.wav, at: 28) == 32_000)  // byte rate = rate * block align
        #expect(u16(Self.wav, at: 32) == 2)  // block align = channels * 2
    }

    @Test func derivedFieldsScaleWithStereoAndRate() {
        let stereo = WavEncoder.wavData(pcm16: Self.pcm, sampleRate: 44_100, channels: 2)
        #expect(u16(stereo, at: 22) == 2)
        #expect(u32(stereo, at: 24) == 44_100)
        #expect(u32(stereo, at: 28) == 176_400)
        #expect(u16(stereo, at: 32) == 4)
    }

    @Test func sizeFieldsMatchPayloadAndSamplesAreVerbatim() {
        #expect(u32(Self.wav, at: 4) == UInt32(36 + Self.pcm.count))  // RIFF size
        #expect(u32(Self.wav, at: 40) == UInt32(Self.pcm.count))  // data-chunk size
        #expect(Self.wav.count == 44 + Self.pcm.count)
        #expect(Self.wav.suffix(Self.pcm.count) == Self.pcm)
    }

    @Test func emptyInputYieldsHeaderOnlyWav() {
        let empty = WavEncoder.wavData(pcm16: Data(), sampleRate: 16_000, channels: 1)
        #expect(empty.count == 44)
        #expect(u32(empty, at: 4) == 36)
        #expect(u32(empty, at: 40) == 0)
    }
}
