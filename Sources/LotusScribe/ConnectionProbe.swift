import Foundation

/// Outcome of a settings connection test. See docs/phase-3-spec.md §3A.
enum ProbeResult: Equatable {
    case success
    case failure(reason: String)
}

/// Headless connection probe (D36): a real round-trip of a ~0.2 s silent WAV
/// plus the DRAFTED model to the DRAFTED STT endpoint — same request shape as
/// TranscriptionService. Reads only its arguments, never SettingsStore.
struct ConnectionProbe {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// ~0.2 s of 16 kHz mono silence: 3200 zero samples × 2 bytes. D28 record:
    /// silence may hallucinate text — irrelevant, the round-trip is the proof.
    private static let silentWav = WavEncoder.wavData(
        pcm16: Data(count: 6400), sampleRate: 16_000, channels: 1)

    /// POSTs the silent WAV with `model` to `endpoint`. Success = HTTP 200 +
    /// decodable `{"text": …}` (content ignored). 10 s timeout (D36).
    func testSTT(endpoint: String, model: String) async -> ProbeResult {
        // D36: un-parseable URL → immediate failure, no network.
        guard SettingsValidation.isValidEndpointURL(endpoint), let url = URL(string: endpoint)
        else { return .failure(reason: "Invalid endpoint URL: \(endpoint)") }

        var body = MultipartBody()
        body.addField(name: "model", value: model)
        body.addFile(
            name: "file", filename: "audio.wav", contentType: "audio/wav", data: Self.silentWav)

        var request = URLRequest(url: url, timeoutInterval: 10)  // D36: 10 s
        request.httpMethod = "POST"
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            return .failure(reason: "Timed out after 10 s")
        } catch {
            return .failure(reason: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(reason: "Unexpected non-HTTP response")
        }
        guard http.statusCode == 200 else {
            return .failure(reason: "HTTP \(http.statusCode)")
        }

        struct TranscriptionResponse: Decodable { let text: String }
        guard (try? JSONDecoder().decode(TranscriptionResponse.self, from: data)) != nil else {
            return .failure(reason: "Unexpected response body (expected {\"text\": …} JSON)")
        }
        return .success
    }
}
