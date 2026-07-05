import Foundation
import Testing
@testable import LotusScribe

/// URLProtocol stub for ConnectionProbe tests. A separate class from
/// StubURLProtocol on purpose: `.serialized` only orders tests within one
/// suite, so sharing that global handler would race TranscriptionServiceTests
/// when suites run in parallel. Also adds an error leg so transport failures
/// and timeouts can be simulated.
final class ProbeStubURLProtocol: URLProtocol {
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

/// ConnectionProbe tests (spec §3A/§3C, D36/D44): stubbed URLSession, never
/// the real network. Global handler → `.serialized`.
@Suite(.serialized)
final class ConnectionProbeTests {
    private let endpoint = "https://stt.test/v1/audio/transcriptions"
    private let llmEndpoint = "https://llm.test/v1/chat/completions"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProbeStubURLProtocol.self]
        session = URLSession(configuration: config)
    }

    deinit {
        ProbeStubURLProtocol.handler = nil
    }

    private func probe() -> ConnectionProbe {
        ConnectionProbe(session: session)
    }

    private static func response(for request: URLRequest, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    /// Extracts the failure reason or records an issue.
    private func failureReason(of result: ProbeResult) -> String? {
        guard case .failure(let reason) = result else {
            Issue.record("expected .failure, got \(result)")
            return nil
        }
        return reason
    }

    @Test func succeedsOn200WithTextJSON() async {
        ProbeStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Data(#"{"text":"any hallucination"}"#.utf8)))
        }
        let result = await probe().testSTT(endpoint: endpoint, model: "whisper-large-v3")
        #expect(result == .success)
    }

    /// D36: same request shape as TranscriptionService — multipart with the
    /// model field and a 0.2 s silent-WAV file part; 10 s timeout.
    @Test func requestCarriesModelFieldAndSilentWavPart() async throws {
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        ProbeStubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return .success((Self.response(for: request), Data(#"{"text":"ok"}"#.utf8)))
        }

        _ = await probe().testSTT(endpoint: endpoint, model: "whisper-large-v3")

        let (request, body) = try #require(captured)
        #expect(request.url?.absoluteString == endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 10)  // D36
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try #require(
            contentType.wholeMatch(of: /multipart\/form-data; boundary=(.+)/)?.1)

        var expected = MultipartBody(boundary: String(boundary))
        expected.addField(name: "model", value: "whisper-large-v3")
        expected.addFile(
            name: "file", filename: "audio.wav", contentType: "audio/wav",
            data: WavEncoder.wavData(pcm16: Data(count: 6400), sampleRate: 16_000, channels: 1))
        #expect(body == expected.data)
    }

    @Test func non200FailsWithStatusInReason() async {
        ProbeStubURLProtocol.handler = { request in
            .success((Self.response(for: request, status: 503), Data("busy".utf8)))
        }
        let result = await probe().testSTT(endpoint: endpoint, model: "m")
        #expect(failureReason(of: result)?.contains("503") == true)
    }

    @Test func transportErrorFails() async {
        ProbeStubURLProtocol.handler = { _ in
            .failure(URLError(.cannotConnectToHost))
        }
        let result = await probe().testSTT(endpoint: endpoint, model: "m")
        #expect(failureReason(of: result)?.isEmpty == false)
    }

    @Test func timeoutFailsWithTimedOutReason() async {
        ProbeStubURLProtocol.handler = { _ in
            .failure(URLError(.timedOut))
        }
        let result = await probe().testSTT(endpoint: endpoint, model: "m")
        #expect(failureReason(of: result)?.contains("Timed out") == true)
    }

    @Test func malformedBodyFails() async {
        ProbeStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Data("not json".utf8)))
        }
        let result = await probe().testSTT(endpoint: endpoint, model: "m")
        #expect(failureReason(of: result)?.isEmpty == false)
    }

    /// D36: un-parseable URL → immediate failure without touching the session.
    @Test func invalidURLFailsWithoutNetwork() async {
        ProbeStubURLProtocol.handler = { _ in
            Issue.record("no request may be sent for an un-parseable URL")
            return .failure(URLError(.badURL))
        }
        let result = await probe().testSTT(endpoint: "not-a-url", model: "m")
        #expect(failureReason(of: result)?.contains("Invalid endpoint URL") == true)
    }

    // MARK: testLLM (spec §3C, D44)

    @Test func llmSucceedsOn200WithChatCompletionJSON() async {
        ProbeStubURLProtocol.handler = { request in
            .success((
                Self.response(for: request),
                Data(#"{"choices":[{"message":{"content":"pong"}}]}"#.utf8)))
        }
        let result = await probe().testLLM(endpoint: llmEndpoint, model: "qwen3-8b")
        #expect(result == .success)
    }

    /// D44: minimal, strictly standard chat completion — body key-set exactly
    /// {model, messages, max_tokens} (no keep_alive), user("ping"),
    /// max_tokens 1, 10 s timeout.
    @Test func llmRequestMatchesSpec() async throws {
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        ProbeStubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return .success(
                (Self.response(for: request), Data(#"{"choices":[{"message":{}}]}"#.utf8)))
        }

        _ = await probe().testLLM(endpoint: llmEndpoint, model: "qwen3-8b")

        let (request, body) = try #require(captured)
        #expect(request.url?.absoluteString == llmEndpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 10)  // D44
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(json.keys) == ["model", "messages", "max_tokens"])  // D44: no keep_alive
        #expect(json["model"] as? String == "qwen3-8b")
        #expect(json["max_tokens"] as? Int == 1)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages == [["role": "user", "content": "ping"]])
    }

    @Test func llmNon200FailsWithStatusInReason() async {
        ProbeStubURLProtocol.handler = { request in
            .success((Self.response(for: request, status: 404), Data("nope".utf8)))
        }
        let result = await probe().testLLM(endpoint: llmEndpoint, model: "m")
        #expect(failureReason(of: result)?.contains("404") == true)
    }

    /// D44: 200 without a decodable `choices[0].message` is a failure.
    @Test func llmMissingChoicesFails() async {
        ProbeStubURLProtocol.handler = { request in
            .success((Self.response(for: request), Data(#"{"choices":[]}"#.utf8)))
        }
        let result = await probe().testLLM(endpoint: llmEndpoint, model: "m")
        #expect(failureReason(of: result)?.isEmpty == false)
    }

    /// D44: same invalid-URL mapping as testSTT — no network touched.
    @Test func llmInvalidURLFailsWithoutNetwork() async {
        ProbeStubURLProtocol.handler = { _ in
            Issue.record("no request may be sent for an un-parseable URL")
            return .failure(URLError(.badURL))
        }
        let result = await probe().testLLM(endpoint: "not-a-url", model: "m")
        #expect(failureReason(of: result)?.contains("Invalid endpoint URL") == true)
    }
}
