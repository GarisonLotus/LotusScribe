import Foundation
import Security

/// Generic-password Keychain wrapper over the Security framework (D7 — own
/// wrapper, no third-party dep). See docs/phase-0-spec.md §Sub-phase 0B.
///
/// Items are scoped to `service` (D10: bundle ID in production; tests use a
/// suffixed service so the real Keychain stays clean). Accounts in production
/// are "stt-api-key" and "llm-api-key".
struct KeychainStore {
    /// Thrown when a Security call returns an unexpected OSStatus.
    struct KeychainError: Error {
        let status: OSStatus
    }

    private let service: String

    init(service: String = "com.garisonlotus.LotusScribe") {
        self.service = service
    }

    /// Stores `secret` for `account`, overwriting any existing item.
    func set(_ secret: String, for account: String) throws {
        // Delete-then-add is the simplest overwrite strategy for a single item.
        try delete(account)

        var query = baseQuery(for: account)
        query[kSecValueData as String] = Data(secret.utf8)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    /// Returns the secret for `account`, or nil if no item exists.
    func get(_ account: String) throws -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data else { throw KeychainError(status: errSecDecode) }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the item for `account`. Deleting a missing item is not an error.
    func delete(_ account: String) throws {
        let status = SecItemDelete(baseQuery(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
