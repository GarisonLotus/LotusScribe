import Testing
@testable import LotusScribe

/// CleanupLevel tests (spec §3B, D40): resolve mapping + verbatim prompt
/// fixtures. The prompt strings are spec fixtures — a drift here silently
/// changes cleanup behavior, so they are asserted byte-for-byte.
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

    @Test func offHasNoSystemPrompt() {
        #expect(CleanupLevel.off.systemPrompt == nil)
    }

    @Test func standardPromptMatchesSpecFixture() {
        #expect(
            CleanupLevel.standard.systemPrompt
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like), fix "
                + "punctuation and capitalization, and add paragraph breaks where "
                + "natural. Preserve the speaker's meaning, wording, and voice — "
                + "never rephrase, summarize, shorten, or add content. "
                + "Output only the cleaned text, with no commentary.")
    }

    @Test func lightPromptMatchesSpecFixture() {
        #expect(
            CleanupLevel.light.systemPrompt
                == "/no_think You clean up dictated speech-to-text transcripts. "
                + "Remove filler and pause words (um, uh, you know, like) and fix "
                + "punctuation and capitalization only. Change nothing else. "
                + "Output only the cleaned text, with no commentary.")
    }
}
