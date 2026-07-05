import Testing
@testable import LotusScribe

/// CleanupLevel tests (spec §3B D40, §4A D51): resolve mapping + prompt
/// composition fixtures. The prompt strings are spec fixtures — a drift
/// here silently changes cleanup behavior, so they are asserted
/// byte-for-byte; the `.other` fixtures ARE the D51 neutrality invariant
/// (Phase-3 behavior is the floor — do not edit them).
struct CleanupLevelTests {
    @Test func nilResolvesToStandard() {
        #expect(CleanupLevel.resolve(nil) == .standard)
    }

    @Test func unrecognizedResolvesToStandard() {
        #expect(CleanupLevel.resolve("aggressive") == .standard)
    }

    @Test func knownRawValuesResolveToThemselves() {
        #expect(CleanupLevel.resolve("off") == .off)
        #expect(CleanupLevel.resolve("light") == .light)
        #expect(CleanupLevel.resolve("standard") == .standard)
    }

    @Test func offHasNoSystemPromptForAnyCategory() {
        for category in AppCategory.allCases {
            #expect(CleanupLevel.off.systemPrompt(for: category) == nil)
        }
    }

    // MARK: D51 neutrality invariant — BYTE-IDENTITY floor.
    // These literals are the pre-4A D45 fixtures verbatim. If composition
    // ever fails to reproduce them, `.other`/nil-bundle dictation has
    // drifted from Phase-3 behavior — fix the composition, NOT the fixture.

    @Test func otherStandardPromptIsByteIdenticalToPhase3Fixture() {
        #expect(
            CleanupLevel.standard.systemPrompt(for: .other)
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like), fix "
                + "punctuation and capitalization, and add paragraph breaks where "
                + "natural. Preserve the speaker's meaning, wording, and voice — "
                + "never rephrase, summarize, shorten, or add content. "
                + "Output only the cleaned text, with no commentary.")
    }

    @Test func otherLightPromptIsByteIdenticalToPhase3Fixture() {
        #expect(
            CleanupLevel.light.systemPrompt(for: .other)
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like) and fix "
                + "punctuation and capitalization only. Change nothing else. "
                + "Output only the cleaned text, with no commentary.")
    }

    // MARK: D51 toned composition — per-category × per-level.

    /// Full verbatim fixture for one toned combo, pinning the exact
    /// composition rule (spaces, ordering) end to end.
    @Test func emailStandardPromptMatchesComposedFixture() {
        #expect(
            CleanupLevel.standard.systemPrompt(for: .email)
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like), fix "
                + "punctuation and capitalization, and add paragraph breaks where "
                + "natural. Preserve the speaker's meaning, wording, and voice — "
                + "never rephrase, summarize, shorten, or add content. "
                + "This text will be sent as an email. Punctuate, capitalize, "
                + "and paragraph it in a clear, professional email register. "
                + "Output only the cleaned text, with no commentary.")
    }

    /// Full verbatim fixture for a toned LIGHT combo — tone weaves into
    /// both levels (D51).
    @Test func personalMessagingLightPromptMatchesComposedFixture() {
        #expect(
            CleanupLevel.light.systemPrompt(for: .personalMessaging)
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like) and fix "
                + "punctuation and capitalization only. Change nothing else. "
                + "This text is a casual personal message. Keep the register "
                + "relaxed and informal — do not formalize the speaker's wording. "
                + "Output only the cleaned text, with no commentary.")
    }

    /// Structural D51 rule for every toned category × level:
    /// `"/no_think " + otherPrompt-body… + toneClause + " " + closer` —
    /// i.e. the toned prompt is the `.other` prompt with the tone spliced
    /// immediately before the (final) closer.
    @Test func tonedPromptsSpliceToneBeforeFinalCloser() throws {
        let closer = "Output only the cleaned text, with no commentary."
        let tonedCategories: [AppCategory] = [.email, .workMessaging, .personalMessaging, .code]
        for level in [CleanupLevel.light, .standard] {
            let neutral = try #require(level.systemPrompt(for: .other))
            for category in tonedCategories {
                let toned = try #require(level.systemPrompt(for: category))
                let tone = try #require(category.toneClause)
                let expected =
                    String(neutral.dropLast(closer.count)) + tone + " " + closer
                #expect(toned == expected)
            }
        }
    }
}
