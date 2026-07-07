import Testing
@testable import LotusScribe

/// Phase 9E (D86): pure collision-lookup tests — the picker's inline warning
/// for hotkeys macOS already claims. The UI rendering is thin (HUMAN-AT-SCREEN);
/// the mapping itself is what must not drift.
struct HotkeyCollisionTests {
    @Test func bareF5LeadsWithHoldingCommandAndKeepsBothPanes() {
        let warning = HotkeyCollision.warning(for: .functionKey(5))
        #expect(warning != nil)
        // D103: bare F5 now LEADS with the working ⌘F5 path — the copy says
        // to hold Command, demoting the disable-Dictation path to optional.
        #expect(warning?.message.contains("Command") == true)
        // Bare F5 is still double-claimed (Keyboard→Dictation AND Siri's
        // "Hold Dictation key") — the user must be linked to BOTH panes.
        #expect(warning?.links.count == 2)
        #expect(warning?.links.contains {
            $0.url.contains("Siri-Settings") } == true)
        #expect(warning?.links.contains {
            $0.url.contains("Keyboard-Settings") } == true)
    }

    @Test func commandF5DefaultIsClean() {
        // D103: the ⌘F5 default is the working path — NO alarm on it.
        #expect(HotkeyCollision.warning(for: .custom("cmd+f5")) == nil)
    }

    @Test func customFnWarnsWithKeyboardPane() {
        for spelling in ["fn", "FN"] {
            let warning = HotkeyCollision.warning(for: .custom(spelling))
            #expect(warning != nil)
            #expect(warning?.links.count == 1)
            #expect(warning?.links.first?.url.contains("Keyboard-Settings") == true)
        }
    }

    @Test(arguments: [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12])
    func otherFunctionKeysAreClean(_ n: Int) {
        #expect(HotkeyCollision.warning(for: .functionKey(n)) == nil)
    }

    @Test func customCombosAreClean() {
        #expect(HotkeyCollision.warning(for: .custom("ctrl+alt+cmd+9")) == nil)
        // Modified F5 dodges the bare-key system shortcuts — intentionally clean.
        #expect(HotkeyCollision.warning(for: .custom("shift+f5")) == nil)
    }

    @Test func spellingVariantsResolveToTheSameWarning() {
        // R9E-2/3: the lookup matches the resolved chord, so a custom "f5" is
        // the F5 warning and a whitespace-padded "fn" still warns.
        #expect(HotkeyCollision.warning(for: .custom("f5"))
            == HotkeyCollision.warning(for: .functionKey(5)))
        #expect(HotkeyCollision.warning(for: .custom(" fn ")) != nil)
        // Unparseable custom text has no chord — never warns.
        #expect(HotkeyCollision.warning(for: .custom("banana")) == nil)
    }
}
