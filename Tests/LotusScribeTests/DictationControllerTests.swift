import Testing
@testable import LotusScribe

/// Empty-audio guard: captures under ~0.1 s (payload < 3200 bytes past the
/// 44-byte WAV header) must not reach Whisper — it hallucinates on silence.
struct DictationControllerTests {
    @Test func headerOnlyWavIsUnusable() {
        #expect(!DictationController.hasUsableAudio(wavByteCount: 44))
    }

    @Test func justBelowThresholdIsUnusable() {
        #expect(!DictationController.hasUsableAudio(wavByteCount: 44 + 3199))
    }

    @Test func thresholdAndAboveIsUsable() {
        #expect(DictationController.hasUsableAudio(wavByteCount: 44 + 3200))
        #expect(DictationController.hasUsableAudio(wavByteCount: 100_000))
    }
}
