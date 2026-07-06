import Testing
@testable import LotusScribe

/// DictionaryPrompt tests (spec docs/phase-5-spec.md §5A, D57/D59). The
/// cleanup-clause string is a spec fixture — asserted byte-for-byte, like
/// the D45/D51 prompt fixtures. Store-side normalization (trim/dedup) is
/// covered in SettingsStoreTests, not re-tested here.
struct DictionaryPromptTests {
    // MARK: cleanupClause (D57 — verbatim fixture, uncapped)

    @Test func cleanupClauseIsNilForEmptyTerms() {
        #expect(DictionaryPrompt.cleanupClause(terms: []) == nil)
    }

    @Test func cleanupClauseMatchesFixtureForOneTerm() {
        #expect(
            DictionaryPrompt.cleanupClause(terms: ["Garison"])
                == "These terms are spelled exactly as written: Garison.")
    }

    @Test func cleanupClauseJoinsTermsInListOrder() {
        #expect(
            DictionaryPrompt.cleanupClause(terms: ["Garison", "LotusScribe", "vLLM"])
                == "These terms are spelled exactly as written: Garison, LotusScribe, vLLM.")
    }

    /// D59: the cleanup clause is UNCAPPED — a list whose join exceeds the
    /// STT budget still reaches the LLM stage in full.
    @Test func cleanupClauseCarriesFullListBeyondSTTBudget() throws {
        let terms = (1...100).map { "Term\($0)Xxxxxxxxx" }  // join ≫ 600 chars
        let clause = try #require(DictionaryPrompt.cleanupClause(terms: terms))
        #expect(clause.count > DictionaryPrompt.sttPromptCharacterBudget)
        #expect(clause.hasSuffix("Term100Xxxxxxxxx."))
    }

    // MARK: sttPrompt (D59 — first-N in list order, 600-char budget)

    @Test func sttPromptIsNilForEmptyTerms() {
        #expect(DictionaryPrompt.sttPrompt(terms: []) == nil)
    }

    @Test func sttPromptJoinsTermsInListOrder() {
        #expect(
            DictionaryPrompt.sttPrompt(terms: ["Garison", "LotusScribe", "vLLM"])
                == "Garison, LotusScribe, vLLM")
    }

    /// Boundary: a join landing exactly ON the budget keeps every term.
    @Test func sttPromptKeepsTermThatFitsExactlyAtBudget() {
        let first = String(repeating: "a", count: 500)
        let second = String(repeating: "b", count: 98)  // 500 + 2 + 98 = 600
        #expect(
            DictionaryPrompt.sttPrompt(terms: [first, second]) == first + ", " + second)
    }

    /// Boundary: one char past the budget drops the term — truncation is
    /// deterministic first-N (D59), so everything after the drop goes too.
    @Test func sttPromptDropsTermsFromFirstOverflowOnward() {
        let first = String(repeating: "a", count: 500)
        let second = String(repeating: "b", count: 99)  // 500 + 2 + 99 = 601
        #expect(DictionaryPrompt.sttPrompt(terms: [first, second, "tiny"]) == first)
    }

    /// D59: a single absurd term degrades to itself, never to nil — the
    /// first term is always included even when it alone exceeds the budget.
    @Test func sttPromptKeepsOversizedFirstTerm() {
        let oversized = String(repeating: "x", count: 700)
        #expect(DictionaryPrompt.sttPrompt(terms: [oversized, "next"]) == oversized)
    }
}
