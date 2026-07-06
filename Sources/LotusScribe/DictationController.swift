import AppKit
import Carbon
import Foundation
import os

/// Main-actor owner of the dictation loop (spec §1D wiring): hotkey
/// start → recorder.start(); stop → TranscriptionService → non-empty
/// transcript → TextInserter. Sole driver of the display-only pill
/// (spec §2C) — show/update/push/hide only, never reads pill state.
@MainActor
final class DictationController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "DictationController")

    private let recorder = AudioRecorder()
    private let transcription = TranscriptionService(settings: SettingsStore())
    private let cleanup = CleanupService(settings: SettingsStore())
    private let inserter = TextInserter()
    private let pill = PillController()
    private var isRecording = false

    /// False until the current capture's first level arrives (D29b —
    /// warming → recording only when the engine is demonstrably live).
    private var engineLive = false

    init() {
        recorder.onLevel = { [weak self] level in
            // Delivered on the main queue (D32); hop onto the actor the
            // same way AppDelegate's hotkey callback does.
            MainActor.assumeIsolated { self?.handleLevel(level) }
        }
    }

    /// D29b: the first level of a capture proves the engine is live —
    /// pill flips warming → recording (waveform = "speak now"); every
    /// level feeds the waveform bars.
    private func handleLevel(_ level: Float) {
        // Late main-queue dispatch can land after stop() — drop it.
        guard isRecording else { return }
        if !engineLive {
            engineLive = true
            Self.logger.info("engine live — first level \(level, privacy: .public)")
            pill.update(.recording)
        }
        pill.push(level: level)
    }

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

    /// D74: last record-start warm-up fired (nil = never this launch).
    private var lastRecordWarmUp: Date?

    /// D74: ≥ 30 s between record-start warm-ups — covers hotkey spam and
    /// rapid re-records without stacking cold loads (cold start 3–10 s,
    /// warm-up timeout 30 s). Eviction inside a 30 s window is a
    /// multi-client race the D43 raw fallback already absorbs.
    nonisolated static func shouldFireRecordWarmUp(now: Date, last: Date?) -> Bool {
        last.map { now.timeIntervalSince($0) >= 30 } ?? true
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

    /// D52: frontmost app at key-down — the app the user is dictating INTO.
    /// Snapshotted per-Task in stopRecording (D23 discipline).
    private var capturedBundleID: String?

    private func startRecording() {
        // D63 invariant — guard BEFORE the generation bump, order
        // load-bearing: a blocked press must not invalidate an in-flight
        // prior dictation (D23/D43). isRecording stays false → key-up no-ops.
        guard !IsSecureEventInputEnabled() else {
            Self.logger.info("secure input active — dictation blocked")
            pill.show(.blocked)
            return
        }
        generation += 1  // D23: invalidates any still-in-flight transcript.
        engineLive = false
        // D52: capture at key-down, not at cleanup time — by then the user
        // may have switched apps. Nil (no frontmost) degrades to .other.
        capturedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Self.logger.info(
            "frontmost at key-down: \(self.capturedBundleID ?? "nil", privacy: .public)")
        do {
            try recorder.start()
            isRecording = true
            pill.show(.warming)
            // D74 (amends D42's trigger set): warm the model while the user
            // speaks — after a SUCCESSFUL start only, so blocked/failed
            // presses fire nothing. Fire-and-forget; warmUp() is log-only
            // and self-skips when cleanup isn't effective-enabled.
            if Self.shouldFireRecordWarmUp(now: Date(), last: lastRecordWarmUp) {
                lastRecordWarmUp = Date()
                Task { await cleanup.warmUp() }
            }
        } catch {
            // Failure policy (spec §cross-cutting): log + error flash.
            Self.logger.error(
                "recorder start failed: \(String(describing: error), privacy: .public)")
            pill.show(.error)
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
            pill.hide()  // spec §2C: tap-length press — no error flash
            return
        }
        pill.update(.processing)

        let capturedGeneration = generation
        // D52/D23: snapshot so this Task carries its own dictation's app —
        // a newer capture can never bleed into an older in-flight Task.
        let capturedBundleID = capturedBundleID
        Task {
            do {
                var text = try await transcription.transcribe(wav: wav)
                guard capturedGeneration == generation else {
                    // D23: a newer dictation started while this one was
                    // in flight — drop, never paste stale text; a stale
                    // result never touches the pill (spec §2C).
                    Self.logger.info(
                        "stale transcript dropped (generation \(capturedGeneration))")
                    return
                }
                guard !text.isEmpty else {
                    // Failure policy (spec §cross-cutting): empty → no paste.
                    Self.logger.info("empty transcript — nothing inserted")
                    pill.hide()
                    return
                }
                Self.logger.info("transcript: \(text, privacy: .public)")
                var terminal = PillState.success
                if cleanup.isEnabled {
                    // D47: transcript accepted — check 1 green + slot 2
                    // pending BEFORE the cleanup await; the visible wait is
                    // the information (bounded by CleanupService's timeout).
                    pill.update(.stagedSuccess(cleanup: .pending))
                    do {
                        text = try await cleanup.cleanup(
                            transcript: text, frontmostBundleID: capturedBundleID)
                        terminal = .stagedSuccess(cleanup: .done)
                    } catch {
                        // D43: never eat the user's words — any cleanup
                        // failure falls back to the raw transcript; no alert.
                        // D47 amends the pill face only: miss → amber slot 2.
                        terminal = .stagedSuccess(cleanup: .missed)
                        Self.logger.error(
                            "cleanup failed — inserting raw transcript: \(String(describing: error), privacy: .public)")
                    }
                    guard capturedGeneration == generation else {
                        // D43: the cleanup await widens the stale window —
                        // re-check; stale never inserts or touches the pill.
                        Self.logger.info(
                            "stale transcript dropped after cleanup (generation \(capturedGeneration))")
                        return
                    }
                }
                inserter.insert(text)
                pill.update(terminal)
            } catch {
                // Failure policy (spec §cross-cutting): log + error flash —
                // but stale failures never touch the pill (D23/spec §2C).
                Self.logger.error(
                    "transcription failed: \(String(describing: error), privacy: .public)")
                if capturedGeneration == generation {
                    pill.update(.error)
                }
            }
        }
    }
}
