import Foundation
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

    /// D74 debounce: never fired this launch → warm-up fires.
    @Test func recordWarmUpFiresWhenNeverFired() {
        #expect(DictationController.shouldFireRecordWarmUp(now: Date(), last: nil))
    }

    /// D74 debounce: under 30 s since the last fire → suppressed.
    @Test func recordWarmUpSuppressedInsideWindow() {
        let now = Date()
        #expect(
            !DictationController.shouldFireRecordWarmUp(
                now: now, last: now.addingTimeInterval(-29.9)))
    }

    /// D74 debounce: exactly 30 s (boundary) → fires again.
    @Test func recordWarmUpFiresAtWindowBoundary() {
        let now = Date()
        #expect(
            DictationController.shouldFireRecordWarmUp(
                now: now, last: now.addingTimeInterval(-30)))
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
