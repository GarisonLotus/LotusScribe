import Foundation
import Testing
@testable import LotusScribe

/// Unit tests for the pure RMS math (D32) — spec §2A known-signal cases.
struct AudioLevelTests {
    /// Little-endian Int16 PCM data from sample values.
    private func pcm(_ samples: [Int16]) -> Data {
        samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    @Test func emptyDataIsZero() {
        #expect(AudioLevel.rms(pcm16: Data()) == 0)
    }

    @Test func silenceIsZero() {
        #expect(AudioLevel.rms(pcm16: pcm([Int16](repeating: 0, count: 1024))) == 0)
    }

    @Test func fullScaleSquareWaveIsOne() {
        let square = (0..<1024).map { $0 % 2 == 0 ? Int16.max : -Int16.max }
        #expect(AudioLevel.rms(pcm16: pcm(square)) == 1.0)
    }

    @Test func halfScaleSquareWaveIsAboutHalf() {
        let half = Int16.max / 2
        let square = (0..<1024).map { $0 % 2 == 0 ? half : -half }
        let level = AudioLevel.rms(pcm16: pcm(square))
        #expect(abs(level - 0.5) < 0.001)
    }

    @Test func trailingOddByteIsIgnored() {
        var data = pcm([Int16.max])
        data.append(0x7F)  // half a sample — must not skew or crash
        #expect(AudioLevel.rms(pcm16: data) == 1.0)
    }
}
