import Foundation
import Testing
@testable import LotusScribe

/// EndpointPreset tests (spec §7A, D69): table contents, apply fills only
/// non-nil URL fields on the draft, model fields never overwritten, apply
/// is idempotent. Draft-only (D26) — no controller, no probes.
@MainActor
final class EndpointPresetTests {
    private let suiteName = "com.garisonlotus.LotusScribe.tests.\(UUID().uuidString)"

    deinit {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private func makeDraft() throws -> SettingsDraft {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return SettingsDraft(store: SettingsStore(defaults: defaults))
    }

    private func preset(_ name: String) throws -> EndpointPreset {
        try #require(EndpointPreset.all.first { $0.name == name })
    }

    // MARK: table contents (D69)

    @Test func tableListsThePresetsInMenuOrder() {
        #expect(EndpointPreset.all.map(\.name) == [
            "Speaches (recommended for STT)", "Ollama", "vLLM",
        ])
    }

    @Test func speachesPresetIsSTTOnly() throws {
        let speaches = try preset("Speaches (recommended for STT)")
        #expect(speaches.sttEndpointURL == "http://localhost:8000/v1/audio/transcriptions")
        #expect(speaches.llmEndpointURL == nil)
    }

    @Test func ollamaPresetIsLLMOnly() throws {
        let ollama = try preset("Ollama")
        #expect(ollama.sttEndpointURL == nil)
        #expect(ollama.llmEndpointURL == "http://localhost:11434/v1/chat/completions")
    }

    @Test func vllmPresetFillsBothEndpoints() throws {
        let vllm = try preset("vLLM")
        #expect(vllm.sttEndpointURL == "http://localhost:8000/v1/audio/transcriptions")
        #expect(vllm.llmEndpointURL == "http://localhost:8000/v1/chat/completions")
    }

    // MARK: apply semantics (D69)

    // A nil URL field means "no opinion" — the draft's existing value
    // survives an STT-only preset.
    @Test func applyFillsOnlyNonNilURLFields() throws {
        let draft = try makeDraft()
        draft.sttEndpointURL = "https://old-stt.example.com"
        draft.llmEndpointURL = "https://keep-llm.example.com"

        try preset("Speaches (recommended for STT)").apply(to: draft)

        #expect(draft.sttEndpointURL == "http://localhost:8000/v1/audio/transcriptions")
        #expect(draft.llmEndpointURL == "https://keep-llm.example.com")
    }

    // Models are server-specific — the user's models must survive preset
    // switching (D69).
    @Test func applyNeverOverwritesModelFields() throws {
        let draft = try makeDraft()
        draft.sttModel = "whisper-large-v3"
        draft.llmModel = "qwen3"

        try preset("vLLM").apply(to: draft)

        #expect(draft.sttModel == "whisper-large-v3")
        #expect(draft.llmModel == "qwen3")
    }

    @Test func applyTwiceIsIdempotent() throws {
        let draft = try makeDraft()
        let vllm = try preset("vLLM")

        vllm.apply(to: draft)
        let afterFirst = (draft.sttEndpointURL, draft.llmEndpointURL)
        vllm.apply(to: draft)

        #expect(draft.sttEndpointURL == afterFirst.0)
        #expect(draft.llmEndpointURL == afterFirst.1)
    }
}
