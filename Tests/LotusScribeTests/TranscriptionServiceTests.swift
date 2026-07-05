import Foundation
import Testing
@testable import LotusScribe

/// In-process URLProtocol stub (D19) — no localhost listener, no real
/// network. The handler is process-global static state, so the suite below
/// runs `.serialized`.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands URLProtocol the body as a stream, not `httpBody` —
    /// drain it so tests can assert the exact bytes sent.
    static func bodyData(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }

        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 4096)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// TranscriptionService tests: isolated UserDefaults suite (0B pattern),
/// stubbed URLSession — never `.standard` defaults, never the real network.
@Suite(.serialized)
final class TranscriptionServiceTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let settings: SettingsStore
    private let session: URLSession

    private let endpoint = "https://stt.test/v1/audio/transcriptions"
    private let wav = Data([0x52, 0x49, 0x46, 0x46, 0x00, 0xFF])

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        settings = SettingsStore(defaults: defaults)
        settings.sttEndpointURL = endpoint
        settings.sttModel = "whisper-large-v3"

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
    }

    deinit {
        StubURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func service() -> TranscriptionService {
        TranscriptionService(settings: settings, session: session)
    }

    private static func okResponse(for request: URLRequest, status: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    @Test func requestMatchesSpec() async throws {
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        StubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return (Self.okResponse(for: request), Data(#"{"text":"ok"}"#.utf8))
        }

        _ = try await service().transcribe(wav: wav)

        let (request, body) = try #require(captured)
        #expect(request.url?.absoluteString == endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 20)  // R12: 20 s per PLAN

        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try #require(
            contentType.wholeMatch(of: /multipart\/form-data; boundary=(.+)/)?.1)

        // Rebuild the expected bytes with the request's own boundary: model
        // field, no language (unset → omitted, D18), then the WAV file part.
        var expected = MultipartBody(boundary: String(boundary))
        expected.addField(name: "model", value: "whisper-large-v3")
        expected.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", data: wav)
        #expect(body == expected.data)
    }

    @Test func languageFieldSentWhenConfigured() async throws {
        settings.sttLanguage = "en"
        nonisolated(unsafe) var captured: (request: URLRequest, body: Data)?
        StubURLProtocol.handler = { request in
            captured = (request, StubURLProtocol.bodyData(of: request))
            return (Self.okResponse(for: request), Data(#"{"text":"ok"}"#.utf8))
        }

        _ = try await service().transcribe(wav: wav)

        let (request, body) = try #require(captured)
        let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
        let boundary = try #require(
            contentType.wholeMatch(of: /multipart\/form-data; boundary=(.+)/)?.1)

        var expected = MultipartBody(boundary: String(boundary))
        expected.addField(name: "model", value: "whisper-large-v3")
        expected.addField(name: "language", value: "en")
        expected.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", data: wav)
        #expect(body == expected.data)
    }

    @Test func successDecodesText() async throws {
        StubURLProtocol.handler = { request in
            (Self.okResponse(for: request), Data(#"{"text":"hello world"}"#.utf8))
        }
        let text = try await service().transcribe(wav: wav)
        #expect(text == "hello world")
    }

    @Test func non200MapsToHTTPError() async {
        StubURLProtocol.handler = { request in
            (Self.okResponse(for: request, status: 503), Data("busy".utf8))
        }
        do {
            _ = try await service().transcribe(wav: wav)
            Issue.record("expected TranscriptionError.http")
        } catch TranscriptionError.http(let status) {
            #expect(status == 503)
        } catch {
            Issue.record("expected .http, got \(error)")
        }
    }

    @Test func malformedJSONMapsToBadResponse() async {
        StubURLProtocol.handler = { request in
            (Self.okResponse(for: request), Data("not json".utf8))
        }
        do {
            _ = try await service().transcribe(wav: wav)
            Issue.record("expected TranscriptionError.badResponse")
        } catch TranscriptionError.badResponse {
            // expected
        } catch {
            Issue.record("expected .badResponse, got \(error)")
        }
    }

    @Test func unsetSettingsThrowNotConfigured() async {
        settings.sttEndpointURL = nil
        StubURLProtocol.handler = { request in
            Issue.record("no request should be sent when unconfigured")
            return (Self.okResponse(for: request), Data())
        }
        do {
            _ = try await service().transcribe(wav: wav)
            Issue.record("expected TranscriptionError.notConfigured")
        } catch TranscriptionError.notConfigured {
            // expected
        } catch {
            Issue.record("expected .notConfigured, got \(error)")
        }
    }
}
