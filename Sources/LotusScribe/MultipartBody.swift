import Foundation

/// Pure multipart/form-data builder (RFC 2046 framing, CRLF line endings).
/// See docs/phase-1-spec.md §"Sub-phase 1C". Boundary is injectable so
/// tests can assert the exact body bytes.
struct MultipartBody {
    let boundary: String
    private var parts = Data()

    init(boundary: String = "LotusScribe-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    /// Value for the request's Content-Type header.
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Complete body: accumulated parts plus the closing boundary.
    var data: Data {
        var body = parts
        body.appendUTF8("--\(boundary)--\r\n")
        return body
    }

    mutating func addField(name: String, value: String) {
        parts.appendUTF8("--\(boundary)\r\n")
        parts.appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n")
        parts.appendUTF8("\r\n")
        parts.appendUTF8("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        parts.appendUTF8("--\(boundary)\r\n")
        parts.appendUTF8(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        parts.appendUTF8("Content-Type: \(contentType)\r\n")
        parts.appendUTF8("\r\n")
        parts.append(data)
        parts.appendUTF8("\r\n")
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(contentsOf: Array(string.utf8))
    }
}
