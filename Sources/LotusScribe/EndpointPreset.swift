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

    /// Menu contents, in menu order (D69 localhost defaults).
    static let all: [EndpointPreset] = [
        EndpointPreset(
            name: "Speaches (recommended for STT)",
            sttEndpointURL: "http://localhost:8000/v1/audio/transcriptions",
            llmEndpointURL: nil),
        EndpointPreset(
            name: "Ollama",
            sttEndpointURL: nil,
            llmEndpointURL: "http://localhost:11434/v1/chat/completions"),
        EndpointPreset(
            name: "vLLM",
            sttEndpointURL: "http://localhost:8000/v1/audio/transcriptions",
            llmEndpointURL: "http://localhost:8000/v1/chat/completions"),
    ]

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
