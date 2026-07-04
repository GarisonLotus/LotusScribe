import AppKit
import Testing
@testable import LotusScribe

/// Smoke test: the hosted test bundle loads and links against the app target.
@Test func appDelegateInitializes() {
    #expect(AppDelegate() is NSApplicationDelegate)
}
