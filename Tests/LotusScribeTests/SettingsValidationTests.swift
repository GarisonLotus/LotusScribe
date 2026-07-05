import Testing
@testable import LotusScribe

/// Pure URL-hint validation for the settings pane (spec §1E): http/https
/// scheme + non-empty host. Validation is advisory — persistence of invalid
/// values is the pane's concern, not tested here.
struct SettingsValidationTests {
    @Test func acceptsHTTPAndHTTPSURLsWithHost() {
        #expect(SettingsValidation.isValidEndpointURL(
            "https://vllm.garison.com/v1/audio/transcriptions"))
        #expect(SettingsValidation.isValidEndpointURL("http://localhost:8000/v1"))
        // Scheme comparison is case-insensitive per RFC 3986.
        #expect(SettingsValidation.isValidEndpointURL("HTTPS://Example.com"))
    }

    @Test func rejectsNonHTTPSchemesAndHostlessStrings() {
        #expect(!SettingsValidation.isValidEndpointURL(""))
        #expect(!SettingsValidation.isValidEndpointURL("not a url"))
        #expect(!SettingsValidation.isValidEndpointURL("ftp://example.com"))
        #expect(!SettingsValidation.isValidEndpointURL("file:///tmp/audio.wav"))
        // No scheme at all.
        #expect(!SettingsValidation.isValidEndpointURL("example.com/v1"))
        // Scheme but no host.
        #expect(!SettingsValidation.isValidEndpointURL("https://"))
        #expect(!SettingsValidation.isValidEndpointURL("https:///path-only"))
    }
}
