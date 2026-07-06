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

    /// D18: optional STT language; nil → omitted from requests. Not a D9
    /// settings-pane key — seeded via `defaults write` only in Phase 1.
    var sttLanguage: String? {
        get { normalizedString(forKey: "sttLanguage") }
        set { defaults.set(newValue, forKey: "sttLanguage") }
    }

    /// D25 empty→nil applied at read time (R39): a raw `defaults write` of ""
    /// bypasses draft.save's normalization, and an empty string must never
    /// count as "set" for effective-enabled checks (D40).
    private func normalizedString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key), !value.isEmpty else { return nil }
        return value
    }
}
