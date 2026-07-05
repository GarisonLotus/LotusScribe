import Foundation

/// App-aware taxonomy for cleanup tone (spec docs/phase-4-spec.md §4A,
/// D50): Wispr's five categories, keyed by EXACT bundle ID — no prefix or
/// wildcard rules; the override map (D53) covers the long tail. Pure
/// Foundation-only: overrides arrive as an argument (D14 headless split);
/// the NSWorkspace read lives in DictationController (D52). Browsers stay
/// unmapped → `.other` (D55).
enum AppCategory: String, CaseIterable {
    case email
    case workMessaging
    case personalMessaging
    case code
    case other

    /// Human-readable name for the settings picker (4C).
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .workMessaging: return "Work Messaging"
        case .personalMessaging: return "Personal Messaging"
        case .code: return "Code"
        case .other: return "Other"
        }
    }

    /// Register/formatting guidance woven into the cleanup prompt (D51).
    /// Verbatim spec fixtures — subordinate to the level body (never
    /// instructs rephrasing). `.other` → nil: with no tone term the
    /// composed prompt stays byte-identical to Phase 3 (D51 invariant).
    var toneClause: String? {
        switch self {
        case .email:
            return "This text will be sent as an email. Punctuate, capitalize, "
                + "and paragraph it in a clear, professional email register."
        case .workMessaging:
            return "This text is a workplace chat message. Keep the register "
                + "concise and professional, conversational rather than formal."
        case .personalMessaging:
            return "This text is a casual personal message. Keep the register "
                + "relaxed and informal — do not formalize the speaker's wording."
        case .code:
            return "This text is for a coding context (editor, terminal, or "
                + "commit message). Preserve technical terms, identifiers, and "
                + "symbols exactly as spoken."
        case .other:
            return nil
        }
    }

    /// Built-in exact bundle-ID map (D50, spec §4A list). Representative,
    /// not exhaustive — user-extensible via overrides (D53; Q4-1 batches
    /// user confirmation of these contents).
    private static let builtInMap: [String: AppCategory] = [
        "com.apple.mail": .email,
        "com.microsoft.Outlook": .email,
        "com.readdle.smartemail-Mac": .email,
        "org.mozilla.thunderbird": .email,
        "com.tinyspeck.slackmacgap": .workMessaging,
        "com.microsoft.teams2": .workMessaging,
        "com.microsoft.teams": .workMessaging,
        "com.apple.MobileSMS": .personalMessaging,
        "net.whatsapp.WhatsApp": .personalMessaging,
        "ru.keepcoder.Telegram": .personalMessaging,
        "com.tdesktop.Telegram": .personalMessaging,
        "org.whispersystems.signal-desktop": .personalMessaging,
        "com.hnc.Discord": .personalMessaging,
        "com.apple.dt.Xcode": .code,
        "com.microsoft.VSCode": .code,
        "com.todesktop.230313mzl4w4u92": .code,  // Cursor
        "com.apple.Terminal": .code,
        "com.googlecode.iterm2": .code,
        "dev.warp.Warp-Stable": .code,
        "com.mitchellh.ghostty": .code,
    ]

    /// D50/D53 resolution: nil id → `.other`; a valid override rawValue
    /// beats the built-in map; a garbage override value is IGNORED and
    /// falls through (safe-resolution mirror of D40's `resolve` — a stale
    /// override can never break dictation); unmatched → `.other`.
    static func category(
        forBundleID id: String?, overrides: [String: String]
    ) -> AppCategory {
        guard let id else { return .other }
        if let raw = overrides[id], let overridden = AppCategory(rawValue: raw) {
            return overridden
        }
        return builtInMap[id] ?? .other
    }
}
