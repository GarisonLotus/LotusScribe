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

    /// Launch-blocking regression (D34): AudioRecorder once called
    /// engine.prepare() in init on an empty graph, raising an NSException
    /// inside DictationController() that AppKit swallowed at launch. This
    /// test crashes the suite if construction ever raises again.
    @Test @MainActor func constructionDoesNotRaise() {
        let controller: DictationController? = DictationController()
        #expect(controller != nil)
    }
}
