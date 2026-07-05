import Foundation

/// Errors surfaced by TranscriptionService (spec §1C).
enum TranscriptionError: Error {
    case notConfigured
    case http(Int)
    case badResponse
    case transport(Error)
}

/// Headless STT client: multipart POST of a WAV payload to the configured
/// OpenAI-compatible transcription endpoint. See docs/phase-1-spec.md
/// §"Sub-phase 1C". Never touches TCC-bearing APIs; no API-key header in
/// Phase 1 (D13).
struct TranscriptionService {
    private let settings: SettingsStore
    private let session: URLSession

    init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    /// POSTs `wav` and returns the transcribed text from `{"text": …}`.
    func transcribe(wav: Data) async throws -> String {
        guard
            let endpoint = settings.sttEndpointURL,
            let url = URL(string: endpoint),
            let model = settings.sttModel
        else { throw TranscriptionError.notConfigured }

        var body = MultipartBody()
        body.addField(name: "model", value: model)
        // D18: optional language field; nil → omitted entirely.
        if let language = settings.sttLanguage {
            body.addField(name: "language", value: language)
        }
        body.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", data: wav)

        var request = URLRequest(url: url, timeoutInterval: 20)  // 20 s per PLAN
        request.httpMethod = "POST"
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TranscriptionError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError.badResponse
        }
        guard http.statusCode == 200 else {
            throw TranscriptionError.http(http.statusCode)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data)
        else { throw TranscriptionError.badResponse }
        return decoded.text
    }
}
