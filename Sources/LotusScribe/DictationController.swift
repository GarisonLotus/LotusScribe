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
