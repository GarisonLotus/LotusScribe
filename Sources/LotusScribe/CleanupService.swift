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

    /// Wraps transcript text in the `<transcript>` data boundary the system
    /// prompt's closer names (D107).
    private static func wrap(_ text: String) -> String {
        "<transcript>\n" + text + "\n</transcript>"
    }

    /// D107 few-shot: each input IS an instruction/question; each output is
    /// that same text merely CLEANED (filler removed, punctuation/caps fixed),
    /// never acted on. Demonstrating the mapping is what actually stops a small
    /// local model from obeying a dictated command — prose framing alone did
    /// not. Kept to transformations both `.light` and `.standard` agree on
    /// (no paragraph breaks, no rephrasing), so the examples never mis-teach a
    /// level.
    private static let fewShot: [(input: String, output: String)] = [
        ("um so like can you give me a quick summary of the meeting you know",
         "Can you give me a quick summary of the meeting?"),
        ("ask me questions until you understand what i want and uh keep going till you're sure",
         "Ask me questions until you understand what I want, and keep going till you're sure."),
    ]

    /// Assemble the chat turns: system prompt, the few-shot demonstrations,
    /// then the real transcript — all transcript turns wrapped identically.
    private static func messages(systemPrompt: String, transcript: String) -> [Message] {
        var messages = [Message(role: "system", content: systemPrompt)]
        for example in fewShot {
            messages.append(Message(role: "user", content: wrap(example.input)))
            messages.append(Message(role: "assistant", content: example.output))
        }
        messages.append(Message(role: "user", content: wrap(transcript)))
        return messages
    }

    /// Chat-completion body. Nil optionals are omitted from the JSON —
    /// that omission is what keeps the hot path strictly standard (D42).
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        var temperature: Double?
        var maxTokens: Int?
        var keepAlive: Int?
        var reasoningEffort: String?

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case maxTokens = "max_tokens"
            case keepAlive = "keep_alive"
            case reasoningEffort = "reasoning_effort"
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
    /// (D39: never insert emptiness for spoken words). 8 s timeout (D45).
    /// `frontmostBundleID` (D52 — explicit, no default: a forgotten
    /// pass-through must not compile) resolves to an AppCategory here at
    /// request time, with a fresh overrides read (D40 live-read posture).
    func cleanup(transcript: String, frontmostBundleID: String?) async throws -> String {
        let category = AppCategory.category(
            forBundleID: frontmostBundleID, overrides: settings.appCategoryOverrides)
        let dictionary = settings.dictionaryTerms  // D56/D57 — fresh read, D40 live-read posture
        Self.logger.info("cleanup category: \(category.rawValue, privacy: .public)")
        guard
            let endpoint = settings.llmEndpointURL,
            let url = URL(string: endpoint),
            let model = settings.llmModel,
            let prompt = CleanupLevel.resolve(settings.cleanupLevel)
                .systemPrompt(for: category, dictionary: dictionary)
        else { throw CleanupError.notConfigured }

        let body = ChatRequest(
            model: model,
            messages: Self.messages(systemPrompt: prompt, transcript: transcript),
            temperature: 0,
            // D72: read at request time (D40 live-read posture); nil → omitted.
            reasoningEffort: settings.suppressModelReasoning ? "none" : nil)
        let request = makeRequest(url: url, body: body, timeout: 8)  // D45: 8 s

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
            let model = settings.llmModel
        else {
            Self.logger.info("warm-up skipped — cleanup not effective-enabled")
            return
        }
        // R38: an unparseable URL is its own skip reason, not "not enabled".
        guard let url = URL(string: endpoint) else {
            Self.logger.info("warm-up skipped — llmEndpointURL is not a parseable URL")
            return
        }

        var body = ChatRequest(
            model: model,
            messages: [Message(role: "user", content: "ok")],
            maxTokens: 1,
            keepAlive: -1,
            // D72: warm-up warms the REAL inference path (8B), so it carries
            // the same conditional as cleanup().
            reasoningEffort: settings.suppressModelReasoning ? "none" : nil)

        let status = await sendWarmUp(url: url, body: body)
        if let status, !(200...299).contains(status) {
            // D72: the retry drops keep_alive ONLY (the known offender);
            // reasoning_effort is a standard OpenAI-API field and stays.
            Self.logger.info("warm-up HTTP \(status) — retrying once without keep_alive")
            body.keepAlive = nil
            let retryStatus = await sendWarmUp(url: url, body: body)
            // R38: no Optional() wrapper — nil status means transport failure.
            let outcome = retryStatus.map { "HTTP \($0)" } ?? "transport failure"
            Self.logger.info("warm-up retry outcome: \(outcome, privacy: .public)")
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
