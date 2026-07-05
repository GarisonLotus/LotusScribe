import Foundation

/// UserDefaults-backed settings storage. See docs/phase-0-spec.md §Sub-phase 0B.
///
/// Keys are the four D9 keys plus `sttLanguage` (D18); all default nil.
/// Secrets never live here — API keys go through KeychainStore.
final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var sttEndpointURL: String? {
        get { defaults.string(forKey: "sttEndpointURL") }
        set { defaults.set(newValue, forKey: "sttEndpointURL") }
    }

    var sttModel: String? {
        get { defaults.string(forKey: "sttModel") }
        set { defaults.set(newValue, forKey: "sttModel") }
    }

    var llmEndpointURL: String? {
        get { defaults.string(forKey: "llmEndpointURL") }
        set { defaults.set(newValue, forKey: "llmEndpointURL") }
    }

    var llmModel: String? {
        get { defaults.string(forKey: "llmModel") }
        set { defaults.set(newValue, forKey: "llmModel") }
    }

    /// D40: cleanup level raw value ("off"/"light"/"standard"); nil or
    /// unrecognized resolves to `.standard` via `CleanupLevel.resolve`.
    /// Settings-pane picker arrives in 3C — until then `defaults write` only.
    var cleanupLevel: String? {
        get { defaults.string(forKey: "cleanupLevel") }
        set { defaults.set(newValue, forKey: "cleanupLevel") }
    }

    /// D18: optional STT language; nil → omitted from requests. Not a D9
    /// settings-pane key — seeded via `defaults write` only in Phase 1.
    var sttLanguage: String? {
        get { defaults.string(forKey: "sttLanguage") }
        set { defaults.set(newValue, forKey: "sttLanguage") }
    }
}
