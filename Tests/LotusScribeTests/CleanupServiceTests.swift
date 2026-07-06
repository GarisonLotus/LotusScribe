import Foundation
import Testing
@testable import LotusScribe

/// URLProtocol stub dedicated to CleanupServiceTests. A separate class per
/// the 3A precedent: `.serialized` only orders tests within one suite, so
/// sharing another suite's global handler would race when suites run in
/// parallel. Result-based so transport failures can be simulated.
final class CleanupStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler:
        ((URLRequest) -> Result<(HTTPURLResponse, Data), Error>)?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.handler?(request) {
        case .success((let response, let data)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
        }
    }

    override func stopLoading() {}
}

/// CleanupService tests (spec §3B, D39/D40/D42): isolated UserDefaults
/// suite, stubbed URLSession — never `.standard` defaults, never the real
/// network. Timing and the live dictation loop are HUMAN-AT-SCREEN.
@Suite(.serialized)
final class CleanupServiceTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let settings: SettingsStore
    private let session: URLSession

    private let endpoint = "https://llm.test/v1/chat/completions"

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        settings = SettingsStore(defaults: defaults)
        settings.llmEndpointURL = endpoint
        settings.llmModel = "qwen3-8b"

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CleanupStubURLProtocol.self]
        session = URLSession(configuration: config)
    }

    deinit {
        CleanupStubURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func service() -> CleanupService {
        CleanupService(settings: settings, session: session)
    }

    private static func response(for request: URLRequest, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    /// Minimal chat-completion reply: {"choices":[{"message":{"content": …}}]}.
    private static func contentJSON(_ content: String) -> Data {
        try! JSONSerialization.data(
            withJSONObject: ["choices": [["message": ["content": content]]]])
    }

    /// Decodes a captured request body as a JSON object.
    private static func json(_ body: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    // MARK: cleanup(transcript:frontmostBundleID:)

    /// D39/D42/D72: hot-path body is strictly OpenAI-standard — model,
    /// system+user messages, temperature 0, plus `reasoning_effort: "none"`
    /// (suppressModelReasoning defaults TRUE) and NOTHING else (no
    /// keep_alive, no max_tokens); 8 s timeout (D45). Nil bundle ID →
    /// `.other` → the D45 prompt unchanged (D51 neutrality invariant at
    /// request level).
    @Test func cleanupRequestMatchesSpec() async throws {
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        CleanupStubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await service().cleanup(transcript: "um hello", frontmostBundleID: nil)

        let (request, body) = try #require(captured)
        #expect(request.url?.absoluteString == endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 8)  // D45: 8 s
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try Self.json(body)
        // D42: no keep_alive; D72: reasoning_effort rides the default-ON setting.
        #expect(Set(json.keys) == ["model", "messages", "temperature", "reasoning_effort"])
        #expect(json["model"] as? String == "qwen3-8b")
        #expect(json["temperature"] as? Double == 0)
        #expect(json["reasoning_effort"] as? String == "none")

        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] == "system")
        // cleanupLevel unset → resolves to .standard (D40); nil bundle ID
        // → .other (D50); dictionary unset → empty (D56) → byte-identical
        // Phase-3/4 prompt (D51/D57 neutrality floor at request level).
        #expect(
            messages[0]["content"]
                == CleanupLevel.standard.systemPrompt(for: .other, dictionary: []))
        #expect(messages[1] == ["role": "user", "content": "um hello"])
    }

    /// D72: suppress OFF → the field is omitted entirely — the key set
    /// drops back to the pre-8A strictly-standard hot-path body.
    @Test func suppressOffOmitsReasoningEffortFromCleanup() async throws {
        settings.suppressModelReasoning = false
        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await service().cleanup(transcript: "hi", frontmostBundleID: nil)

        let json = try Self.json(try #require(captured))
        #expect(Set(json.keys) == ["model", "messages", "temperature"])
    }

    @Test func lightLevelSendsLightSystemPrompt() async throws {
        settings.cleanupLevel = "light"
        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await service().cleanup(transcript: "hi", frontmostBundleID: nil)

        let json = try Self.json(try #require(captured))
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(
            messages[0]["content"]
                == CleanupLevel.light.systemPrompt(for: .other, dictionary: []))
    }

    /// D52: a mapped bundle ID resolves inside the service — the request
    /// body carries the category-composed system prompt (D51).
    @Test func mappedBundleIDSendsCategoryComposedPrompt() async throws {
        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await service().cleanup(
            transcript: "hi", frontmostBundleID: "com.apple.mail")

        let json = try Self.json(try #require(captured))
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(
            messages[0]["content"]
                == CleanupLevel.standard.systemPrompt(for: .email, dictionary: []))
    }

    /// D52/D53: overrides are read from the service's own store at request
    /// time (live-read posture, like isEnabled/D40) — an override written
    /// after the service exists still redirects the category.
    @Test func overridesAreReadFromStoreAtRequestTime() async throws {
        let cleanupService = service()
        settings.appCategoryOverrides = ["com.apple.mail": "personalMessaging"]

        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await cleanupService.cleanup(
            transcript: "hi", frontmostBundleID: "com.apple.mail")

        let json = try Self.json(try #require(captured))
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(
            messages[0]["content"]
                == CleanupLevel.standard.systemPrompt(for: .personalMessaging, dictionary: []))
    }

    /// D57: terms in the store weave the dictionary clause into the
    /// request's system prompt.
    @Test func dictionaryTermsInStoreWeaveClauseIntoSystemPrompt() async throws {
        settings.dictionaryTerms = ["Garison", "LotusScribe"]
        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await service().cleanup(transcript: "hi", frontmostBundleID: nil)

        let json = try Self.json(try #require(captured))
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(
            messages[0]["content"]
                == CleanupLevel.standard.systemPrompt(
                    for: .other, dictionary: ["Garison", "LotusScribe"]))
    }

    /// D56/D57: dictionary terms are read from the service's own store at
    /// request time (live-read posture, like overrides/D53) — terms written
    /// after the service exists still reach the prompt.
    @Test func dictionaryTermsAreReadFromStoreAtRequestTime() async throws {
        let cleanupService = service()
        settings.dictionaryTerms = ["vLLM"]

        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("cleaned")))
        }

        _ = try await cleanupService.cleanup(transcript: "hi", frontmostBundleID: nil)

        let json = try Self.json(try #require(captured))
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(
            messages[0]["content"]
                == CleanupLevel.standard.systemPrompt(for: .other, dictionary: ["vLLM"]))
    }

    @Test func successReturnsTrimmedContent() async throws {
        CleanupStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Self.contentJSON("\n  Hello world.  \n")))
        }
        let text = try await service().cleanup(transcript: "hello world", frontmostBundleID: nil)
        #expect(text == "Hello world.")
    }

    /// D39: trimmed-empty output throws — never insert emptiness for
    /// spoken words (the caller falls back to the raw transcript).
    @Test func whitespaceOnlyContentThrowsEmptyOutput() async {
        CleanupStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Self.contentJSON("  \n ")))
        }
        do {
            _ = try await service().cleanup(transcript: "hello", frontmostBundleID: nil)
            Issue.record("expected CleanupError.emptyOutput")
        } catch CleanupError.emptyOutput {
            // expected
        } catch {
            Issue.record("expected .emptyOutput, got \(error)")
        }
    }

    @Test func non200ThrowsHTTPError() async {
        CleanupStubURLProtocol.handler = { request in
            .success((Self.response(for: request, status: 503), Data("busy".utf8)))
        }
        do {
            _ = try await service().cleanup(transcript: "hello", frontmostBundleID: nil)
            Issue.record("expected CleanupError.http")
        } catch CleanupError.http(let status) {
            #expect(status == 503)
        } catch {
            Issue.record("expected .http, got \(error)")
        }
    }

    /// URLError(.timedOut) is the runtime face of the 8 s ceiling — it must
    /// map to .transport so the pipeline's raw fallback catches it (D43).
    @Test func timedOutMapsToTransport() async {
        CleanupStubURLProtocol.handler = { _ in .failure(URLError(.timedOut)) }
        do {
            _ = try await service().cleanup(transcript: "hello", frontmostBundleID: nil)
            Issue.record("expected CleanupError.transport")
        } catch CleanupError.transport {
            // expected
        } catch {
            Issue.record("expected .transport, got \(error)")
        }
    }

    @Test func malformedJSONThrowsBadResponse() async {
        CleanupStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Data("not json".utf8)))
        }
        do {
            _ = try await service().cleanup(transcript: "hello", frontmostBundleID: nil)
            Issue.record("expected CleanupError.badResponse")
        } catch CleanupError.badResponse {
            // expected
        } catch {
            Issue.record("expected .badResponse, got \(error)")
        }
    }

    // MARK: isEnabled (D40 matrix)

    @Test func isEnabledRequiresURLModelAndNonOffLevel() {
        #expect(service().isEnabled)  // URL + model set, level unset → standard

        settings.cleanupLevel = "off"
        #expect(!service().isEnabled)

        settings.cleanupLevel = "light"
        #expect(service().isEnabled)

        settings.llmModel = nil
        #expect(!service().isEnabled)

        settings.llmModel = "qwen3-8b"
        settings.llmEndpointURL = nil
        #expect(!service().isEnabled)
    }

    // MARK: warmUp() (D42)

    /// D42/D72: warm-up pins the model — user("ok"), max_tokens 1,
    /// keep_alive -1, 30 s timeout; the ONLY request allowed keep_alive.
    /// It carries reasoning_effort too (default-ON) — 8B warms the real
    /// inference path.
    @Test func warmUpRequestMatchesSpec() async throws {
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        CleanupStubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return .success((Self.response(for: request), Self.contentJSON("ok")))
        }

        await service().warmUp()

        let (request, body) = try #require(captured)
        #expect(request.url?.absoluteString == endpoint)
        #expect(request.timeoutInterval == 30)  // D42: cold start 3–10 s

        let json = try Self.json(body)
        #expect(Set(json.keys) == ["model", "messages", "max_tokens", "keep_alive", "reasoning_effort"])
        #expect(json["model"] as? String == "qwen3-8b")
        #expect(json["max_tokens"] as? Int == 1)
        #expect(json["keep_alive"] as? Int == -1)
        #expect(json["reasoning_effort"] as? String == "none")
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "ok"]])
    }

    /// D72: suppress OFF → warm-up omits the field too (same conditional
    /// as cleanup — one setting drives both request shapes).
    @Test func suppressOffOmitsReasoningEffortFromWarmUp() async throws {
        settings.suppressModelReasoning = false
        nonisolated(unsafe) var captured: Data?
        CleanupStubURLProtocol.handler = { request in
            captured = StubURLProtocol.bodyData(of: request)
            return .success((Self.response(for: request), Self.contentJSON("ok")))
        }

        await service().warmUp()

        let json = try Self.json(try #require(captured))
        #expect(Set(json.keys) == ["model", "messages", "max_tokens", "keep_alive"])
    }

    /// D42/D72: non-2xx → exactly one retry, WITHOUT keep_alive (strict
    /// OpenAI-compat validators may 400 on unknown fields) but WITH
    /// reasoning_effort — it is a standard OpenAI-API field and stays.
    @Test func warmUpRetriesOnceWithoutKeepAliveOnNon2xx() async throws {
        nonisolated(unsafe) var bodies: [Data] = []
        CleanupStubURLProtocol.handler = { request in
            bodies.append(StubURLProtocol.bodyData(of: request))
            let status = bodies.count == 1 ? 400 : 200
            return .success((Self.response(for: request, status: status), Self.contentJSON("ok")))
        }

        await service().warmUp()

        #expect(bodies.count == 2)
        let retry = try Self.json(try #require(bodies.last))
        // keep_alive dropped, reasoning_effort kept (D72).
        #expect(Set(retry.keys) == ["model", "messages", "max_tokens", "reasoning_effort"])
    }

    /// D40/D42: warm-up is skipped entirely when cleanup is not
    /// effective-enabled — no request may be sent.
    @Test func warmUpSkippedWhenNotEnabled() async {
        settings.cleanupLevel = "off"
        CleanupStubURLProtocol.handler = { _ in
            Issue.record("no warm-up request may be sent when cleanup is off")
            return .failure(URLError(.badURL))
        }
        await service().warmUp()
    }
}
