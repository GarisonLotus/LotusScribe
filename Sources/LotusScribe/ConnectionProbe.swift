import Foundation

/// Outcome of a settings connection test. See docs/phase-3-spec.md §3A/§3C.
enum ProbeResult: Equatable {
    case success
    case failure(reason: String)
}

/// Headless connection probes (D36/D44): real round-trips to the DRAFTED
/// endpoints — same request shapes as the live services. Reads only its
/// arguments, never SettingsStore.
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

        switch await send(request) {
        case .failure(let failure):
            return .failure(reason: failure.reason)
        case .success(let data):
            struct TranscriptionResponse: Decodable { let text: String }
            guard (try? JSONDecoder().decode(TranscriptionResponse.self, from: data)) != nil else {
                return .failure(reason: "Unexpected response body (expected {\"text\": …} JSON)")
            }
            return .success
        }
    }

    /// D44: minimal chat-completion round-trip — {model, messages:
    /// [user("ping")], max_tokens: 1}, strictly OpenAI-standard (never
    /// keep_alive). Success = HTTP 200 + decodable `choices[0].message`.
    /// 10 s timeout, same invalid-URL / error mapping as `testSTT`.
    func testLLM(endpoint: String, model: String) async -> ProbeResult {
        guard SettingsValidation.isValidEndpointURL(endpoint), let url = URL(string: endpoint)
        else { return .failure(reason: "Invalid endpoint URL: \(endpoint)") }

        struct ChatRequest: Encodable {
            let model: String
            let messages: [[String: String]]
            let maxTokens: Int

            enum CodingKeys: String, CodingKey {
                case model, messages
                case maxTokens = "max_tokens"
            }
        }
        var request = URLRequest(url: url, timeoutInterval: 10)  // D44: 10 s
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Encoding a value type of strings and numbers cannot fail.
        request.httpBody = try! JSONEncoder().encode(
            ChatRequest(
                model: model, messages: [["role": "user", "content": "ping"]], maxTokens: 1))

        switch await send(request) {
        case .failure(let failure):
            return .failure(reason: failure.reason)
        case .success(let data):
            struct ChatResponse: Decodable {
                struct Choice: Decodable {
                    struct Message: Decodable {}
                    let message: Message
                }
                let choices: [Choice]
            }
            guard
                let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
                decoded.choices.first != nil
            else {
                return .failure(reason: "Unexpected response body (expected chat-completion JSON)")
            }
            return .success
        }
    }

    /// Error carrier for `send` (Result's Failure must conform to Error).
    private struct ProbeFailure: Error { let reason: String }

    /// Shared transport + status gate for both probes: transport errors,
    /// non-HTTP responses, and non-200 statuses map to failure reasons;
    /// HTTP 200 hands the body back for endpoint-specific decoding.
    private func send(_ request: URLRequest) async -> Result<Data, ProbeFailure> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            return .failure(ProbeFailure(reason: "Timed out after 10 s"))
        } catch {
            return .failure(ProbeFailure(reason: error.localizedDescription))
        }

        guard let http = response as? HTTPURLResponse else {
            return .failure(ProbeFailure(reason: "Unexpected non-HTTP response"))
        }
        guard http.statusCode == 200 else {
            return .failure(ProbeFailure(reason: "HTTP \(http.statusCode)"))
        }
        return .success(data)
    }
}
