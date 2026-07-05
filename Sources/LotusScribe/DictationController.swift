import Foundation
import os

/// Main-actor owner of the dictation loop (spec §1D wiring): hotkey
/// start → recorder.start(); stop → TranscriptionService → non-empty
/// transcript → TextInserter.
@MainActor
final class DictationController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "DictationController")

    private let recorder = AudioRecorder()
    private let transcription = TranscriptionService(settings: SettingsStore())
    private let inserter = TextInserter()
    private var isRecording = false

    /// D23: overlapping dictation — each start bumps the generation; an
    /// in-flight transcribe Task inserts only if its generation is still
    /// current, else logs + drops. No cancel/serialize plumbing.
    private var generation = 0

    /// True when the WAV holds at least ~0.1 s of audio:
    /// payload = wavByteCount − 44 (WAV header); threshold =
    /// 16000 Hz × 2 bytes/sample × 0.1 s = 3200 bytes.
    nonisolated static func hasUsableAudio(wavByteCount: Int) -> Bool {
        wavByteCount - 44 >= 3200
    }

    func handle(_ action: HotkeyAction) {
        switch action {
        case .startCapture:
            startRecording()
        case .stopCapture:
            stopRecording()
        case .none:
            break
        }
    }

    private func startRecording() {
        generation += 1  // D23: invalidates any still-in-flight transcript.
        do {
            try recorder.start()
            isRecording = true
        } catch {
            // Failure policy (spec §cross-cutting): log, do nothing.
            Self.logger.error(
                "recorder start failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func stopRecording() {
        // Start may have failed (mic denied) — no stop without a start.
        guard isRecording else { return }
        isRecording = false
        let wav = recorder.stop()

        guard Self.hasUsableAudio(wavByteCount: wav.count) else {
            // Defect from live testing: near-empty capture POSTed to Whisper
            // hallucinates a transcript ("you") that would be pasted.
            Self.logger.info(
                "capture too short (\(wav.count) bytes) — skipping transcription")
            return
        }

        let capturedGeneration = generation
        Task {
            do {
                let text = try await transcription.transcribe(wav: wav)
                guard capturedGeneration == generation else {
                    // D23: a newer dictation started while this one was
                    // in flight — drop, never paste stale text.
                    Self.logger.info(
                        "stale transcript dropped (generation \(capturedGeneration))")
                    return
                }
                guard !text.isEmpty else {
                    // Failure policy (spec §cross-cutting): empty → no paste.
                    Self.logger.info("empty transcript — nothing inserted")
                    return
                }
                Self.logger.info("transcript: \(text, privacy: .public)")
                inserter.insert(text)
            } catch {
                // Failure policy (spec §cross-cutting): log, do nothing.
                Self.logger.error(
                    "transcription failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
