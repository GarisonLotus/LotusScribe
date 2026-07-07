import Foundation

/// Endpoint presets for the settings pane (spec docs/phase-7-spec.md §7A,
/// D69): pure stateless table, D40 shape. A nil URL means "this preset has
/// no opinion" — apply leaves that field alone. Model names are
/// server-specific, so `apply` NEVER touches the model fields; there is no
/// persisted "selected preset" — custom = just edit the fields.
struct EndpointPreset {
    let name: String
    let sttEndpointURL: String?
    let llmEndpointURL: String?
    /// D91: suggested model names, carried alongside the endpoint so
    /// onboarding's featured prefill can seed both. `apply(to:)` still never
    /// writes these (D69) — only the one-tap "Use recommended" flow does.
    /// Default nil keeps the synthesized memberwise init source-compatible.
    /// `var` (not `let`): a defaulted `let` is dropped from the memberwise
    /// init, so the featured entries below couldn't pass these values.
    var suggestedSTTModel: String? = nil
    var suggestedLLMModel: String? = nil

    /// D69 localhost defaults. Named so onboarding can reference the featured
    /// two (D91) while the Settings menu still iterates `all` in order.
    static let speaches = EndpointPreset(
        name: "Speaches (recommended for STT)",
        sttEndpointURL: "http://localhost:8000/v1/audio/transcriptions",
        llmEndpointURL: nil,
        suggestedSTTModel: "whisper-large-v3")
    static let ollama = EndpointPreset(
        name: "Ollama",
        sttEndpointURL: nil,
        llmEndpointURL: "http://localhost:11434/v1/chat/completions",
        suggestedLLMModel: "llama3.2:3b")
    static let vllm = EndpointPreset(
        name: "vLLM",
        sttEndpointURL: "http://localhost:8000/v1/audio/transcriptions",
        llmEndpointURL: "http://localhost:8000/v1/chat/completions")

    /// Menu contents, in menu order (D69 localhost defaults).
    static let all: [EndpointPreset] = [speaches, ollama, vllm]

    /// D69 apply semantics: fill ONLY the non-nil URL fields on the DRAFT
    /// (D26 — Save remains the sole store-write path). Idempotent.
    @MainActor
    func apply(to draft: SettingsDraft) {
        if let sttEndpointURL {
            draft.sttEndpointURL = sttEndpointURL
        }
        if let llmEndpointURL {
            draft.llmEndpointURL = llmEndpointURL
        }
    }
}
