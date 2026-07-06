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

    /// System prompt for the cleanup chat completion; `.off` → nil for
    /// every category and dictionary. D57 composition (amends D51's rule
    /// shape): `"/no_think " + levelBody + " " + (toneClause + " ")? +
    /// (dictionaryClause + " ")? + closer`, each optional term omitted
    /// entirely when nil, closer kept FINAL (strongest position).
    /// D51/D57 NEUTRALITY INVARIANT — `.other` with an empty dictionary
    /// composes byte-identical to the D45 Phase-3 fixtures, and an empty
    /// dictionary composes byte-identical to Phase-4 output for every
    /// category × level; guarded byte-for-byte by CleanupLevelTests.
    func systemPrompt(for category: AppCategory, dictionary: [String]) -> String? {
        guard let body = levelBody else { return nil }
        let toneTerm = category.toneClause.map { $0 + " " } ?? ""
        let dictionaryTerm =
            DictionaryPrompt.cleanupClause(terms: dictionary).map { $0 + " " } ?? ""
        return "/no_think " + body + " " + toneTerm + dictionaryTerm
            + "Output only the cleaned text, with no commentary."
    }

    /// Level body segment (verbatim D45 fixture content, docs/phase-3-spec.md
    /// §3B per RESEARCH.md §4); `.off` → nil.
    private var levelBody: String? {
        switch self {
        case .off:
            return nil
        case .light:
            return "You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like) and fix "
                + "punctuation and capitalization only. Change nothing else."
        case .standard:
            return "You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like), fix "
                + "punctuation and capitalization, and add paragraph breaks where "
                + "natural. Preserve the speaker's meaning, wording, and voice — "
                + "never rephrase, summarize, shorten, or add content."
        }
    }
}
