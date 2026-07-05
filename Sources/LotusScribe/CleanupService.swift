import Foundation
import os

/// Errors surfaced by CleanupService (D39 — mirrors TranscriptionError).
enum CleanupError: Error {
    case notConfigured
    case http(Int)
    case badResponse
    case emptyOutput
    case transport(Error)
}

/// Headless LLM cleanup client (spec §3B, D39): OpenAI-standard chat
/// completion POSTed to `llmEndpointURL`. The hot-path body is strictly
/// standard — no `keep_alive` ever (D42); only `warmUp()` may carry it.
struct CleanupService {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "CleanupService")

    private let settings: SettingsStore
    private let session: URLSession

    init(settings: SettingsStore, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    /// D40 effective-enabled rule: endpoint AND model set (D25 empty→nil)
    /// AND resolved level ≠ off.
    var isEnabled: Bool {
        settings.llmEndpointURL != nil
            && settings.llmModel != nil
            && CleanupLevel.resolve(settings.cleanupLevel) != .off
    }

    private struct Message: Encodable { let role: String; let content: String }

    /// Chat-completion body. Nil optionals are omitted from the JSON —
    /// that omission is what keeps the hot path strictly standard (D42).
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        var temperature: Double?
        var maxTokens: Int?
        var keepAlive: Int?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
            case keepAlive = "keep_alive"
        }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    private func makeRequest(url: URL, body: ChatRequest, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Encoding a value type of strings and numbers cannot fail.
        request.httpBody = try! JSONEncoder().encode(body)
        return request
    }

    /// Cleans `transcript` per the resolved level. Success = HTTP 200 +
    /// non-empty trimmed `choices[0].message.content`; trimmed-empty throws
    /// (D39: never insert emptiness for spoken words). 4 s timeout.
    func cleanup(transcript: String) async throws -> String {
        guard
            let endpoint = settings.llmEndpointURL,
            let url = URL(string: endpoint),
            let model = settings.llmModel,
            let prompt = CleanupLevel.resolve(settings.cleanupLevel).systemPrompt
        else { throw CleanupError.notConfigured }

        let body = ChatRequest(
            model: model,
            messages: [
                Message(role: "system", content: prompt),
                Message(role: "user", content: transcript),
            ],
            temperature: 0)
        let request = makeRequest(url: url, body: body, timeout: 4)  // D39: 4 s

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CleanupError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw CleanupError.badResponse }
        guard http.statusCode == 200 else { throw CleanupError.http(http.statusCode) }
        guard
            let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = decoded.choices.first?.message.content
        else { throw CleanupError.badResponse }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CleanupError.emptyOutput }
        return trimmed
    }

    /// D42 warm-up: fire-and-forget, log-only, never touches the pill.
    /// `keep_alive: -1` pins Ollama-style servers; non-2xx → retried ONCE
    /// without the field (strict OpenAI-compat validators may 400 on
    /// unknown fields — vLLM must still warm). Skipped when not
    /// effective-enabled. 30 s timeout (cold start runs 3–10 s).
    func warmUp() async {
        guard
            isEnabled,
            let endpoint = settings.llmEndpointURL,
            let url = URL(string: endpoint),
            let model = settings.llmModel
        else {
            Self.logger.info("warm-up skipped — cleanup not effective-enabled")
            return
        }

        var body = ChatRequest(
            model: model,
            messages: [Message(role: "user", content: "ok")],
            maxTokens: 1,
            keepAlive: -1)

        let status = await sendWarmUp(url: url, body: body)
        if let status, !(200...299).contains(status) {
            Self.logger.info("warm-up HTTP \(status) — retrying once without keep_alive")
            body.keepAlive = nil
            let retryStatus = await sendWarmUp(url: url, body: body)
            Self.logger.info(
                "warm-up retry outcome: \(String(describing: retryStatus), privacy: .public)")
        } else if let status {
            Self.logger.info("warm-up done (HTTP \(status))")
        }
    }

    /// One warm-up request; returns the HTTP status, nil on transport
    /// failure (logged, no retry — D42 retries on non-2xx only).
    private func sendWarmUp(url: URL, body: ChatRequest) async -> Int? {
        do {
            let (_, response) = try await session.data(
                for: makeRequest(url: url, body: body, timeout: 30))
            return (response as? HTTPURLResponse)?.statusCode
        } catch {
            Self.logger.error(
                "warm-up transport failure: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
