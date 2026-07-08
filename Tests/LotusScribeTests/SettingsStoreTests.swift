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

    // R39 regression: a raw `defaults write` of "" bypasses draft.save's
    // D25 empty→nil normalization — the store must apply it at read time so
    // empty strings can never flip effective-enabled checks (D40).
    @Test func emptyStringValuesReadAsNil() {
        defaults.set("", forKey: "llmEndpointURL")
        defaults.set("", forKey: "llmModel")

        let store = SettingsStore(defaults: defaults)
        #expect(store.llmEndpointURL == nil)
        #expect(store.llmModel == nil)
    }

    // MARK: appCategoryOverrides (D53)

    @Test func appCategoryOverridesRoundTrip() {
        let store = SettingsStore(defaults: defaults)
        store.appCategoryOverrides = ["com.apple.mail": "personalMessaging"]
        #expect(
            defaults.dictionary(forKey: "appCategoryOverrides") as? [String: String]
                == ["com.apple.mail": "personalMessaging"])
        #expect(store.appCategoryOverrides == ["com.apple.mail": "personalMessaging"])
    }

    @Test func absentOverridesKeyReadsAsEmptyDict() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.appCategoryOverrides == [:])
    }

    /// D53: empty dict ⇄ absent key — writing empty removes the key.
    @Test func emptyOverridesWriteRemovesKey() {
        let store = SettingsStore(defaults: defaults)
        store.appCategoryOverrides = ["com.apple.mail": "code"]
        store.appCategoryOverrides = [:]
        #expect(defaults.object(forKey: "appCategoryOverrides") == nil)
        #expect(store.appCategoryOverrides == [:])
    }

    /// D53: the getter filters to String values — non-string junk written
    /// via raw `defaults write` is dropped, never crashes resolution.
    @Test func nonStringOverrideValuesAreFiltered() {
        defaults.set(
            ["com.apple.mail": "email", "com.example.junk": 7],
            forKey: "appCategoryOverrides")

        let store = SettingsStore(defaults: defaults)
        #expect(store.appCategoryOverrides == ["com.apple.mail": "email"])
    }

    // MARK: dictionaryTerms (D56)

    @Test func dictionaryTermsRoundTripPreservingOrder() {
        let store = SettingsStore(defaults: defaults)
        store.dictionaryTerms = ["Garison", "LotusScribe"]
        #expect(
            defaults.array(forKey: "dictionaryTerms") as? [String]
                == ["Garison", "LotusScribe"])
        #expect(store.dictionaryTerms == ["Garison", "LotusScribe"])
    }

    @Test func absentDictionaryKeyReadsAsEmptyArray() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.dictionaryTerms == [])
    }

    /// D56: empty array ⇄ absent key — writing empty removes the key.
    @Test func emptyDictionaryWriteRemovesKey() {
        let store = SettingsStore(defaults: defaults)
        store.dictionaryTerms = ["Garison"]
        store.dictionaryTerms = []
        #expect(defaults.object(forKey: "dictionaryTerms") == nil)
        #expect(store.dictionaryTerms == [])
    }

    /// D56/R39: non-string junk from a raw `defaults write` is dropped at
    /// read time — it can never reach prompt composition.
    @Test func nonStringDictionaryValuesAreFiltered() {
        defaults.set(["Garison", 7, true], forKey: "dictionaryTerms")

        let store = SettingsStore(defaults: defaults)
        #expect(store.dictionaryTerms == ["Garison"])
    }

    /// D56: read-time normalization trims whitespace and drops
    /// trimmed-empty terms.
    @Test func dictionaryTermsAreTrimmedAndEmptiesDropped() {
        defaults.set(["  Garison ", "   ", "", "vLLM"], forKey: "dictionaryTerms")

        let store = SettingsStore(defaults: defaults)
        #expect(store.dictionaryTerms == ["Garison", "vLLM"])
    }

    /// D56: case-insensitive dedup keeps the FIRST occurrence (order is
    /// D59 truncation priority).
    @Test func dictionaryDedupIsCaseInsensitiveKeepingFirst() {
        defaults.set(["Garison", "garison", "GARISON", "vLLM"], forKey: "dictionaryTerms")

        let store = SettingsStore(defaults: defaults)
        #expect(store.dictionaryTerms == ["Garison", "vLLM"])
    }

    // MARK: onboardingCompleted (7B, D67)

    /// Absent key → false: a fresh install must show onboarding.
    @Test func onboardingCompletedDefaultsToFalse() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.onboardingCompleted == false)
    }

    @Test func onboardingCompletedRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.onboardingCompleted = true
        #expect(defaults.bool(forKey: "onboardingCompleted") == true)
        #expect(store.onboardingCompleted == true)
    }

    // MARK: suppressModelReasoning (8A, D72)

    /// D72: absent key reads TRUE — `defaults.bool` alone would flip the
    /// default (contrast onboardingCompleted, where absent→false is meant).
    @Test func suppressModelReasoningDefaultsToTrue() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.suppressModelReasoning == true)
    }

    /// D72: written false, then true, round-trips through the raw key.
    @Test func suppressModelReasoningRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.suppressModelReasoning = false
        #expect(defaults.object(forKey: "suppressModelReasoning") != nil)
        #expect(defaults.bool(forKey: "suppressModelReasoning") == false)
        #expect(store.suppressModelReasoning == false)

        store.suppressModelReasoning = true
        #expect(defaults.bool(forKey: "suppressModelReasoning") == true)
        #expect(store.suppressModelReasoning == true)
    }

    @Test func valuesPersistAcrossStoreInstances() {
        let writer = SettingsStore(defaults: defaults)
        writer.sttModel = "whisper-1"

        let reader = SettingsStore(defaults: defaults)
        #expect(reader.sttModel == "whisper-1")
    }

    // MARK: - Phase 9: hotkeyChord

    @Test func hotkeyChordRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.hotkeyChord = "f5"
        #expect(defaults.string(forKey: "hotkeyChord") == "f5")
        #expect(store.hotkeyChord == "f5")
        store.hotkeyChord = "ctrl+alt+cmd+9"
        #expect(store.hotkeyChord == "ctrl+alt+cmd+9")
    }

    @Test func emptyHotkeyChordReadsAsNilAndResolvesToCmdOptionD() {
        let store = SettingsStore(defaults: defaults)
        defaults.set("", forKey: "hotkeyChord")  // raw junk write bypasses UI
        #expect(store.hotkeyChord == nil)
        // D106: absent/empty resolves to the ⌘⌥D default.
        #expect(HotkeyChord.resolved(from: store.hotkeyChord)
            == .combo(keyCode: 2, modifiers: [.maskCommand, .maskAlternate]))
    }

    @Test func absentHotkeyChordResolvesToCmdOptionD() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.hotkeyChord == nil)
        #expect(HotkeyChord.resolved(from: store.hotkeyChord)
            == .combo(keyCode: 2, modifiers: [.maskCommand, .maskAlternate]))
    }

    // MARK: - Phase 11: inputDeviceUID (D110)

    @Test func inputDeviceUIDRoundTrips() {
        let store = SettingsStore(defaults: defaults)
        store.inputDeviceUID = "BuiltInMicrophoneDevice"
        #expect(defaults.string(forKey: "inputDeviceUID") == "BuiltInMicrophoneDevice")
        #expect(store.inputDeviceUID == "BuiltInMicrophoneDevice")
    }

    /// D110/R39: absent key follows system (nil), and a raw `defaults write` of
    /// "" reads nil so an empty UID can never count as a pin.
    @Test func inputDeviceUIDEmptyOrAbsentReadsAsNil() {
        let store = SettingsStore(defaults: defaults)
        #expect(store.inputDeviceUID == nil)
        defaults.set("", forKey: "inputDeviceUID")
        #expect(store.inputDeviceUID == nil)
    }
}
