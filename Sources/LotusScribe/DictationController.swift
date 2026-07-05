import Foundation
import os

/// Main-actor owner of the dictation loop (spec §1C wiring): hotkey
/// start → recorder.start(); stop → TranscriptionService → log the
/// transcript. Insertion is 1D.
@MainActor
final class DictationController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "DictationController")

    private let recorder = AudioRecorder()
    private let transcription = TranscriptionService(settings: SettingsStore())
    private var isRecording = false

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

        let transcription = self.transcription
        Task {
            do {
                let text = try await transcription.transcribe(wav: wav)
                Self.logger.info("transcript: \(text, privacy: .public)")
            } catch {
                // Failure policy (spec §cross-cutting): log, do nothing.
                Self.logger.error(
                    "transcription failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
