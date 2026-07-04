import Foundation
import Testing
@testable import LotusScribe

/// KeychainStore tests use a distinct test service so the app's real Keychain
/// service (`com.garisonlotus.LotusScribe`) is never touched (0B invariant).
/// Each test instance gets a unique account (parallel-safe) and deletes its
/// item in deinit.
final class KeychainStoreTests {
    private let store = KeychainStore(service: "com.garisonlotus.LotusScribe.tests")
    private let account = "test-account-\(UUID().uuidString)"

    deinit {
        try? store.delete(account)
    }

    @Test func getMissingAccountReturnsNil() throws {
        #expect(try store.get(account) == nil)
    }

    @Test func setThenGetRoundTrips() throws {
        try store.set("secret-1", for: account)
        #expect(try store.get(account) == "secret-1")
    }

    @Test func setOverwritesExistingSecret() throws {
        try store.set("old-secret", for: account)
        try store.set("new-secret", for: account)
        #expect(try store.get(account) == "new-secret")
    }

    @Test func deleteRemovesSecret() throws {
        try store.set("secret-1", for: account)
        try store.delete(account)
        #expect(try store.get(account) == nil)
    }

    @Test func deleteOfMissingAccountDoesNotThrow() throws {
        try store.delete(account)
    }
}
