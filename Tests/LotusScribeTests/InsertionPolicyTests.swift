import Testing
@testable import LotusScribe

/// InsertionPolicy route truth table (spec §6B, D61/D65): AX only when
/// the focused element was found AND kAXSelectedText is settable;
/// anything less routes to pasteboard. Headless — the adapter's AX
/// branches are unreachable in the test runner (D49 posture), so this
/// suite carries the routing semantics.
struct InsertionPolicyTests {
    @Test func foundAndSettableRoutesToAX() {
        #expect(
            InsertionPolicy.route(
                focusedElementFound: true, selectedTextSettable: true) == .ax)
    }

    @Test func foundButNotSettableRoutesToPasteboard() {
        #expect(
            InsertionPolicy.route(
                focusedElementFound: true, selectedTextSettable: false) == .pasteboard)
    }

    /// Physically unreachable from the probe (settability is only asked of
    /// a found element) but pinned so the AND can never decay to an OR.
    @Test func settableWithoutFocusedElementRoutesToPasteboard() {
        #expect(
            InsertionPolicy.route(
                focusedElementFound: false, selectedTextSettable: true) == .pasteboard)
    }

    @Test func neitherFoundNorSettableRoutesToPasteboard() {
        #expect(
            InsertionPolicy.route(
                focusedElementFound: false, selectedTextSettable: false) == .pasteboard)
    }
}
