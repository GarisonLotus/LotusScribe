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

    // MARK: - shouldSaveClipboard truth table (spec §6C, D62)

    /// Pre-15.4 the accessBehavior API is absent and no enforcement
    /// exists — reads are always safe, so save/restore proceeds.
    @Test func unavailableGateSavesClipboard() {
        #expect(InsertionPolicy.shouldSaveClipboard(gate: .unavailable))
    }

    /// `.standard` (AppKit `.default`) = no enforcement active today →
    /// read freely (D62).
    @Test func standardGateSavesClipboard() {
        #expect(InsertionPolicy.shouldSaveClipboard(gate: .standard))
    }

    /// A read under `.ask` fires the system alert mid-dictation while the
    /// synthesized Cmd-V is in flight — the paste lands in the dialog
    /// (D43 violation), so save is skipped (Phase-1 clobber, accepted).
    @Test func askGateSkipsSave() {
        #expect(!InsertionPolicy.shouldSaveClipboard(gate: .ask))
    }

    @Test func alwaysAllowGateSavesClipboard() {
        #expect(InsertionPolicy.shouldSaveClipboard(gate: .alwaysAllow))
    }

    @Test func alwaysDenyGateSkipsSave() {
        #expect(!InsertionPolicy.shouldSaveClipboard(gate: .alwaysDeny))
    }

    // MARK: - shouldRestore guard (spec §6C, D62)

    /// No snapshot (the gate skipped save) → nothing to restore, even
    /// when the changeCounts happen to match.
    @Test func noSnapshotNeverRestores() {
        #expect(
            !InsertionPolicy.shouldRestore(
                hasSnapshot: false, writtenChangeCount: 7, currentChangeCount: 7))
    }

    /// A moved changeCount means another writer (user copy, clipboard
    /// manager, newer dictation) owns the board — restore must skip so it
    /// never clobbers newer content.
    @Test func movedChangeCountSkipsRestore() {
        #expect(
            !InsertionPolicy.shouldRestore(
                hasSnapshot: true, writtenChangeCount: 7, currentChangeCount: 8))
    }

    /// Snapshot present and nobody else wrote since our write → restore.
    @Test func snapshotWithUnmovedChangeCountRestores() {
        #expect(
            InsertionPolicy.shouldRestore(
                hasSnapshot: true, writtenChangeCount: 7, currentChangeCount: 7))
    }
}
