import Foundation

/// UserDefaults-backed settings storage. See docs/phase-0-spec.md §Sub-phase 0B.
///
/// Keys are the four D9 keys plus `sttLanguage` (D18) and `cleanupLevel`
/// (D40); all default nil. Empty strings read as nil (D25 at read time, R39).
/// Secrets never live here — API keys go through KeychainStore.
final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var sttEndpointURL: String? {
        get { normalizedString(forKey: "sttEndpointURL") }
        set { defaults.set(newValue, forKey: "sttEndpointURL") }
    }

    var sttModel: String? {
        get { normalizedString(forKey: "sttModel") }
        set { defaults.set(newValue, forKey: "sttModel") }
    }

    var llmEndpointURL: String? {
        get { normalizedString(forKey: "llmEndpointURL") }
        set { defaults.set(newValue, forKey: "llmEndpointURL") }
    }

    var llmModel: String? {
        get { normalizedString(forKey: "llmModel") }
        set { defaults.set(newValue, forKey: "llmModel") }
    }

    /// D40: cleanup level raw value ("off"/"light"/"standard"); nil or
    /// unrecognized resolves to `.standard` via `CleanupLevel.resolve`.
    /// Written by the settings-pane picker (3C).
    var cleanupLevel: String? {
        get { normalizedString(forKey: "cleanupLevel") }
        set { defaults.set(newValue, forKey: "cleanupLevel") }
    }

    /// D53: app-category overrides — bundle ID → AppCategory rawValue.
    /// Get filters the defaults dictionary to String values (non-string
    /// junk dropped); set writes the whole dict; empty dict ⇄ absent key.
    /// Invalid rawValues are ignored at resolution, not here (D53).
    var appCategoryOverrides: [String: String] {
        get {
            (defaults.dictionary(forKey: "appCategoryOverrides") ?? [:])
                .compactMapValues { $0 as? String }
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: "appCategoryOverrides")
            } else {
                defaults.set(newValue, forKey: "appCategoryOverrides")
            }
        }
    }

    /// D56: user dictionary — ordered term list (order is user-meaningful:
    /// first terms survive the D59 STT cap). Get normalizes at READ time
    /// (R39 posture — raw `defaults write` junk never reaches prompt
    /// composition un-normalized): String values only, whitespace-trimmed,
    /// empties dropped, case-insensitive dedup keeping first occurrence.
    /// Set writes the whole array; empty ⇄ absent key (D53 idiom).
    var dictionaryTerms: [String] {
        get {
            var seen = Set<String>()
            return (defaults.array(forKey: "dictionaryTerms") ?? [])
                .compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: "dictionaryTerms")
            } else {
                defaults.set(newValue, forKey: "dictionaryTerms")
            }
        }
    }

    /// D67 (7B): true once the user dismisses first-run onboarding (Skip
    /// or Finish); absent → false, so a fresh install shows the window.
    /// Bool, not a D9 pane key — D25/R39 empty→nil is n/a.
    var onboardingCompleted: Bool {
        get { defaults.bool(forKey: "onboardingCompleted") }
        set { defaults.set(newValue, forKey: "onboardingCompleted") }
    }

    /// D72: true (default) → cleanup/warm-up requests carry
    /// `reasoning_effort: "none"`; false → field omitted (model default).
    /// Absent key must read TRUE — `defaults.bool` alone would flip the
    /// default (contrast onboardingCompleted, where absent→false is meant).
    var suppressModelReasoning: Bool {
        get {
            defaults.object(forKey: "suppressModelReasoning") == nil
                || defaults.bool(forKey: "suppressModelReasoning")
        }
        set { defaults.set(newValue, forKey: "suppressModelReasoning") }
    }

    /// D18: optional STT language; nil → omitted from requests. Not a D9
    /// settings-pane key — seeded via `defaults write` only in Phase 1.
    var sttLanguage: String? {
        get { normalizedString(forKey: "sttLanguage") }
        set { defaults.set(newValue, forKey: "sttLanguage") }
    }

    /// Phase 9 (D83): the push-to-talk hotkey as a `HotkeyChord.parse` string
    /// ("f5", "ctrl+alt+cmd+9", "fn"). Absent/empty → the F5 default via
    /// `HotkeyChord.resolved` (D80). A live write-through setting — the picker
    /// writes here and posts `lotusHotkeyChanged`, NOT a buffered draft field.
    var hotkeyChord: String? {
        get { normalizedString(forKey: "hotkeyChord") }
        set { defaults.set(newValue, forKey: "hotkeyChord") }
    }

    /// D25 empty→nil applied at read time (R39): a raw `defaults write` of ""
    /// bypasses draft.save's normalization, and an empty string must never
    /// count as "set" for effective-enabled checks (D40).
    private func normalizedString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
