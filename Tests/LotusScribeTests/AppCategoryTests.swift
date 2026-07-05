import Testing
@testable import LotusScribe

/// AppCategory tests (spec §4A, D50/D53): resolution matrix, verbatim
/// toneClause fixtures, displayName mapping. All pure/headless — the
/// NSWorkspace read is 4B's adapter and is not under test (D14).
struct AppCategoryTests {
    // MARK: category(forBundleID:overrides:) resolution matrix (D50/D53)

    @Test func nilBundleIDResolvesToOther() {
        #expect(AppCategory.category(forBundleID: nil, overrides: [:]) == .other)
    }

    @Test func unmatchedBundleIDResolvesToOther() {
        #expect(
            AppCategory.category(forBundleID: "com.example.unknown", overrides: [:])
                == .other)
    }

    /// One representative built-in bundle ID per non-other category.
    @Test func builtInMapResolvesRepresentativeApps() {
        #expect(AppCategory.category(forBundleID: "com.apple.mail", overrides: [:]) == .email)
        #expect(
            AppCategory.category(forBundleID: "com.tinyspeck.slackmacgap", overrides: [:])
                == .workMessaging)
        #expect(
            AppCategory.category(forBundleID: "com.apple.MobileSMS", overrides: [:])
                == .personalMessaging)
        #expect(AppCategory.category(forBundleID: "com.apple.dt.Xcode", overrides: [:]) == .code)
    }

    @Test func overrideWinsOverBuiltIn() {
        let overrides = ["com.apple.mail": "personalMessaging"]
        #expect(
            AppCategory.category(forBundleID: "com.apple.mail", overrides: overrides)
                == .personalMessaging)
    }

    /// D53: a garbage override value is IGNORED — falls through to the
    /// built-in map, never breaks resolution.
    @Test func garbageOverrideValueFallsThroughToBuiltIn() {
        let overrides = ["com.apple.mail": "banana"]
        #expect(
            AppCategory.category(forBundleID: "com.apple.mail", overrides: overrides)
                == .email)
    }

    /// A garbage override on an UNMAPPED bundle falls through to .other.
    @Test func garbageOverrideOnUnmappedBundleResolvesToOther() {
        let overrides = ["com.example.unknown": "banana"]
        #expect(
            AppCategory.category(forBundleID: "com.example.unknown", overrides: overrides)
                == .other)
    }

    @Test func overrideOnUnmappedBundleApplies() {
        let overrides = ["com.example.webapp": "workMessaging"]
        #expect(
            AppCategory.category(forBundleID: "com.example.webapp", overrides: overrides)
                == .workMessaging)
    }

    // MARK: toneClause fixtures (D51, verbatim spec §4A)

    @Test func otherHasNoToneClause() {
        #expect(AppCategory.other.toneClause == nil)
    }

    @Test func toneClausesMatchSpecFixtures() {
        #expect(
            AppCategory.email.toneClause
                == "This text will be sent as an email. Punctuate, capitalize, "
                + "and paragraph it in a clear, professional email register.")
        #expect(
            AppCategory.workMessaging.toneClause
                == "This text is a workplace chat message. Keep the register "
                + "concise and professional, conversational rather than formal.")
        #expect(
            AppCategory.personalMessaging.toneClause
                == "This text is a casual personal message. Keep the register "
                + "relaxed and informal — do not formalize the speaker's wording.")
        #expect(
            AppCategory.code.toneClause
                == "This text is for a coding context (editor, terminal, or "
                + "commit message). Preserve technical terms, identifiers, and "
                + "symbols exactly as spoken.")
    }

    // MARK: displayName

    @Test func displayNamesMatchSpec() {
        #expect(AppCategory.email.displayName == "Email")
        #expect(AppCategory.workMessaging.displayName == "Work Messaging")
        #expect(AppCategory.personalMessaging.displayName == "Personal Messaging")
        #expect(AppCategory.code.displayName == "Code")
        #expect(AppCategory.other.displayName == "Other")
    }
}
