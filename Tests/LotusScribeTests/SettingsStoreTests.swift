import Foundation
import Testing
@testable import LotusScribe

/// SettingsStore tests run against an isolated `UserDefaults(suiteName:)` —
/// never `.standard` (0B invariant). Each test instance gets a unique suite
/// (Swift Testing runs tests in parallel) and removes it in deinit.
final class SettingsStoreTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // Round-trips assert the raw defaults key too, guarding the exact key
    // names locked by D9.

    @Test func sttEndpointURLRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.sttEndpointURL = "https://stt.example.com/v1"
        #expect(defaults.string(forKey: "sttEndpointURL") == "https://stt.example.com/v1")
        #expect(store.sttEndpointURL == "https://stt.example.com/v1")
    }

    @Test func sttModelRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.sttModel = "whisper-1"
        #expect(defaults.string(forKey: "sttModel") == "whisper-1")
        #expect(store.sttModel == "whisper-1")
    }

    @Test func llmEndpointURLRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.llmEndpointURL = "https://llm.example.com/v1"
        #expect(defaults.string(forKey: "llmEndpointURL") == "https://llm.example.com/v1")
        #expect(store.llmEndpointURL == "https://llm.example.com/v1")
    }

    @Test func llmModelRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.llmModel = "gpt-4o"
        #expect(defaults.string(forKey: "llmModel") == "gpt-4o")
        #expect(store.llmModel == "gpt-4o")
    }

    @Test func unsetKeysDefaultToNil() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.sttEndpointURL == nil)
        #expect(store.sttModel == nil)
        #expect(store.llmEndpointURL == nil)
        #expect(store.llmModel == nil)
    }

    @Test func valuesPersistAcrossStoreInstances() {
        let writer = SettingsStore(defaults: defaults)
        writer.sttModel = "whisper-1"

        let reader = SettingsStore(defaults: defaults)
        #expect(reader.sttModel == "whisper-1")
    }
}
