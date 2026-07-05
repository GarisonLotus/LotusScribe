import Foundation
import Testing
@testable import LotusScribe

/// MultipartBody framing is byte-for-byte load-bearing (spec §1C invariant:
/// request construction is unit-tested exactly) — a fixed boundary makes the
/// expected bytes deterministic.
struct MultipartBodyTests {
    private let boundary = "test-boundary"

    @Test func contentTypeCarriesBoundary() {
        let body = MultipartBody(boundary: boundary)
        #expect(body.contentType == "multipart/form-data; boundary=test-boundary")
    }

    @Test func emptyBodyIsJustClosingBoundary() {
        let body = MultipartBody(boundary: boundary)
        #expect(body.data == Data("--test-boundary--\r\n".utf8))
    }

    @Test func fieldPartMatchesExactBytes() {
        var body = MultipartBody(boundary: boundary)
        body.addField(name: "model", value: "whisper-large-v3")

        let expected = "--test-boundary\r\n"
            + "Content-Disposition: form-data; name=\"model\"\r\n"
            + "\r\n"
            + "whisper-large-v3\r\n"
            + "--test-boundary--\r\n"
        #expect(body.data == Data(expected.utf8))
    }

    @Test func filePartMatchesExactBytes() {
        var body = MultipartBody(boundary: boundary)
        // Non-UTF8 bytes prove the payload passes through untouched.
        let payload = Data([0x00, 0xFF, 0x10, 0x80])
        body.addFile(name: "file", filename: "audio.wav", contentType: "audio/wav", data: payload)

        var expected = Data(
            ("--test-boundary\r\n"
                + "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n"
                + "Content-Type: audio/wav\r\n"
                + "\r\n").utf8)
        expected.append(payload)
        expected.append(Data("\r\n--test-boundary--\r\n".utf8))
        #expect(body.data == expected)
    }

    @Test func partsAppearInAdditionOrder() {
        var body = MultipartBody(boundary: boundary)
        body.addField(name: "model", value: "m")
        body.addField(name: "language", value: "en")

        let expected = "--test-boundary\r\n"
            + "Content-Disposition: form-data; name=\"model\"\r\n"
            + "\r\n"
            + "m\r\n"
            + "--test-boundary\r\n"
            + "Content-Disposition: form-data; name=\"language\"\r\n"
            + "\r\n"
            + "en\r\n"
            + "--test-boundary--\r\n"
        #expect(body.data == Data(expected.utf8))
    }
}
