import Foundation

/// Pure prompt builders for the custom dictionary (docs/phase-5-spec.md §5A,
/// D57/D59). Foundation-only enum — terms arrive as an argument, never read
/// from SettingsStore here (D14 headless split). No logging: truncation is
/// the STT caller's concern (5B). Both builders return nil for `[]` so
/// callers omit the clause/field entirely — the D57/D58 neutrality floor
/// (empty dictionary → byte-identical Phase-4 output).
enum DictionaryPrompt {
    /// D59: app-side cap for the Whisper initial prompt. Whisper keeps only
    /// the LAST ~224 tokens, so an oversized prompt silently drops the
    /// user's FIRST (highest-priority) terms server-side; ~224 tokens ×
    /// ~3 chars/token for proper nouns ≈ 600 chars, conservative — no
    /// tokenizer in-app (D7).
    static let sttPromptCharacterBudget = 600

    /// Cleanup system-prompt clause (D57 fixture, verbatim; UNCAPPED — the
    /// full list always reaches the LLM stage). Nil for `[]`.
    static func cleanupClause(terms: [String]) -> String? {
        guard !terms.isEmpty else { return nil }
        return "These terms are spelled exactly as written: "
            + terms.joined(separator: ", ") + "."
    }

    /// Whisper initial-prompt value (D59): first-N terms joined ", " in
    /// list order while the result stays ≤ `sttPromptCharacterBudget`; the
    /// FIRST term is always included even if oversized (degrade to
    /// something, never nil). Nil for `[]`.
    static func sttPrompt(terms: [String]) -> String? {
        guard let first = terms.first else { return nil }
        var prompt = first
        for term in terms.dropFirst() {
            let candidate = prompt + ", " + term
            guard candidate.count <= sttPromptCharacterBudget else { break }
            prompt = candidate
        }
        return prompt
    }
}
