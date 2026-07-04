import Foundation
import os

/// Main-actor owner of the dictation loop (spec §1B v1 wiring): hotkey
/// start → recorder.start(); stop → WAV to a temp file, log the path.
/// 1C replaces the temp-file hand-off with TranscriptionService.
@MainActor
final class DictationController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "DictationController")

    private let recorder = AudioRecorder()
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

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LotusScribe-\(UUID().uuidString).wav")
        do {
            try wav.write(to: url)
            Self.logger.info("wav written: \(url.path, privacy: .public)")
        } catch {
            Self.logger.error(
                "wav write failed: \(String(describing: error), privacy: .public)")
        }
    }
}
