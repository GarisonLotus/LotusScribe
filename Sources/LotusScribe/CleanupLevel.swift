import Foundation

/// Cleanup intensity for the LLM stage (D40). Raw values are the
/// `cleanupLevel` defaults-key strings; nil/unrecognized resolves to
/// `.standard`. See docs/phase-3-spec.md §3B.
enum CleanupLevel: String, CaseIterable {
    case off
    case light
    case standard

    /// Maps the raw defaults value to a level. Unset or unrecognized →
    /// `.standard` (D40: a user who saved an LLM endpoint wants cleanup).
    static func resolve(_ raw: String?) -> CleanupLevel {
        raw.flatMap(CleanupLevel.init(rawValue:)) ?? .standard
    }

    /// System prompt for the cleanup chat completion; `.off` → nil.
    /// Verbatim spec fixtures (docs/phase-3-spec.md §3B, per RESEARCH.md §4)
    /// — guarded byte-for-byte by CleanupLevelTests.
    var systemPrompt: String? {
        switch self {
        case .off:
            return nil
        case .light:
            return "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like) and fix "
                + "punctuation and capitalization only. Change nothing else. "
                + "Output only the cleaned text, with no commentary."
        case .standard:
            return "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like), fix "
                + "punctuation and capitalization, and add paragraph breaks where "
                + "natural. Preserve the speaker's meaning, wording, and voice — "
                + "never rephrase, summarize, shorten, or add content. "
                + "Output only the cleaned text, with no commentary."
        }
    }
}
