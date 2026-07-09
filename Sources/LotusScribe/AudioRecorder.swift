import AVFoundation
import os

/// TCC-bearing adapter around AVAudioEngine's input tap (D14). Each tap
/// buffer is converted on the fly to 16 kHz mono Int16 via AVAudioConverter
/// (D17); `stop()` hands the accumulated PCM to pure WavEncoder.
///
/// Degrades gracefully: with no usable input device (mic denied, headless
/// host), `start()` throws and the app keeps running. Spec §1B invariant:
/// the engine runs only between start() and stop().
final class AudioRecorder {
    enum RecorderError: Error {
        /// Input device reports a zero-rate/zero-channel format — no device
        /// or no microphone permission.
        case unusableInputFormat
        case converterUnavailable
    }

    static let outputSampleRate = 16_000
    static let outputChannels = 1

    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "AudioRecorder")

    private let engine = AVAudioEngine()

    /// Device layer for resolving the pinned input UID at `start()` (11B).
    /// Typed as the protocol so a test can inject a stub; default is the edge.
    private let devices: AudioInputDeviceEnumerating = CoreAudioDeviceEnumerator()

    // Tap callbacks arrive on an audio thread while stop() runs on the main
    // thread — every `pcm` access goes through `lock`.
    private let lock = NSLock()
    private var pcm = Data()

    /// Per-chunk normalized RMS (D32), invoked on the main queue. The first
    /// invocation doubles as the engine-live signal (D29 — waveform means
    /// "speak now"). Set before start(). A block dispatched just before
    /// stop() can still land after it returns — consumers guard (R30).
    var onLevel: ((Float) -> Void)?

    /// Installs the input tap and starts the engine. First call in an app's
    /// lifetime triggers the Microphone TCC prompt (tester record #2).
    func start() throws {
        guard !engine.isRunning else { return }

        let input = engine.inputNode
        pinInputDeviceIfChosen(on: input)
        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.unusableInputFormat
        }
        guard
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: Double(Self.outputSampleRate),
                channels: AVAudioChannelCount(Self.outputChannels),
                interleaved: true),
            let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else {
            throw RecorderError.converterUnavailable
        }
        lock.withLock { pcm.removeAll() }
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            self?.appendConverted(buffer, using: converter)
        }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        Self.logger.info(
            "recording started (\(inputFormat.sampleRate, privacy: .public) Hz in)")
    }

    /// Pins the user-chosen input device before the engine runs (11B, §1B:
    /// the device is selected as part of start(), never swapped while running).
    /// The UID is read fresh each start() so a change applies to the NEXT
    /// dictation. Silent fallback (locked §2): a nil/unresolved UID — or any
    /// pin error (D88 posture) — leaves the engine on the system default;
    /// never throws, never aborts the recording.
    private func pinInputDeviceIfChosen(on input: AVAudioInputNode) {
        guard
            let uid = SettingsStore().inputDeviceUID,
            let deviceID = AudioInputDevice.resolvedID(forUID: uid, in: devices.inputDevices())
        else {
            Self.logger.info("input device: system default")
            return
        }
        do {
            try input.auAudioUnit.setDeviceID(deviceID)
            Self.logger.info("input device pinned (id \(deviceID, privacy: .public))")
        } catch {
            Self.logger.error(
                "input device pin failed; using system default: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Stops the engine and returns the capture as a 16 kHz/mono/16-bit WAV.
    func stop() -> Data {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let samples = lock.withLock {
            let captured = pcm
            pcm.removeAll()
            return captured
        }
        Self.logger.info("recording stopped (\(samples.count, privacy: .public) PCM bytes)")
        return WavEncoder.wavData(
            pcm16: samples, sampleRate: Self.outputSampleRate, channels: Self.outputChannels)
    }

    /// Audio-thread tap: converts one device-format buffer to the output
    /// format and appends its bytes. Conversion errors drop the buffer and
    /// log — never crash the audio thread (spec failure policy).
    private func appendConverted(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) {
        let ratio = converter.outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard
            let output = AVAudioPCMBuffer(
                pcmFormat: converter.outputFormat, frameCapacity: capacity)
        else { return }

        // Streaming pattern: hand the converter this one buffer, then report
        // "no more for now" so it flushes what it can and returns.
        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let conversionError {
            Self.logger.error(
                "buffer conversion failed: \(conversionError.localizedDescription, privacy: .public)")
            return
        }

        guard let channelData = output.int16ChannelData, output.frameLength > 0 else { return }
        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size  // mono, interleaved
        let chunk = Data(bytes: channelData[0], count: byteCount)
        lock.withLock { pcm.append(chunk) }

        // D32: RMS computed here on the audio thread, only the Float crosses
        // to the main queue.
        if let onLevel {
            let level = AudioLevel.rms(pcm16: chunk)
            DispatchQueue.main.async { onLevel(level) }
        }
    }
}
