import Foundation

/// UserDefaults-backed settings storage. See docs/phase-0-spec.md §Sub-phase 0B.
///
/// Keys are exactly the four below (D9); all default nil. Secrets never live
/// here — API keys go through KeychainStore.
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
}
