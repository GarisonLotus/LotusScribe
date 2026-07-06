import CoreGraphics
import Testing
@testable import LotusScribe

/// Unit tests for the pure 1A/2A hotkey logic (spec invariant: hotkey logic
/// is 100% unit-tested pure code). Actions assert on `.action`; the D30
/// swallow matrix has its own section. Comparisons use `HotkeyAction.none`
/// spelled out to avoid any reading ambiguity with `Optional.none`.
struct HotkeyStateMachineTests {
    /// ctrl+alt+z — kVK_ANSI_Z is 6.
    private static let ctrlAltZ = HotkeyChord.combo(
        keyCode: 6, modifiers: [.maskControl, .maskAlternate])

    // MARK: - fnHold

    @Test func fnPressStartsAndReleaseStopsAcrossCycles() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)).action == .startCapture)
        #expect(machine.handle(.flagsChanged([])).action == .stopCapture)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)).action == .startCapture)
        #expect(machine.handle(.flagsChanged([])).action == .stopCapture)
    }

    @Test func repeatedFlagsChangedInSameStateIsIdempotent() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)).action == .startCapture)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)).action == HotkeyAction.none)
        #expect(machine.handle(.flagsChanged([])).action == .stopCapture)
        #expect(machine.handle(.flagsChanged([])).action == HotkeyAction.none)
    }

    @Test func fnReleaseWithoutPriorPressEmitsNothing() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged([])).action == HotkeyAction.none)
    }

    @Test func fnHoldIgnoresKeyDownAndKeyUp() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.keyDown(6, [.maskControl])).action == HotkeyAction.none)
        #expect(machine.handle(.keyUp(6)).action == HotkeyAction.none)
    }

    // MARK: - combo actions

    @Test func comboKeyDownStartsAndKeyUpStops() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).action == .startCapture)
        #expect(machine.handle(.keyUp(6)).action == .stopCapture)
    }

    @Test func comboMatchesWithExtraFlagBitsPresent() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        let realWorldFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskNonCoalesced]
        #expect(machine.handle(.keyDown(6, realWorldFlags)).action == .startCapture)
    }

    @Test func nonMatchingKeyCodeEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(7, [.maskControl, .maskAlternate])).action
            == HotkeyAction.none)
    }

    @Test func missingRequiredModifierEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl])).action == HotkeyAction.none)
    }

    @Test func duplicateKeyDownWhileCapturingEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).action == .startCapture)
        // OS key-repeat delivers duplicate downs while held.
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).action
            == HotkeyAction.none)
        #expect(machine.handle(.keyUp(6)).action == .stopCapture)
    }

    @Test func modifierReleaseWhileCapturingStops() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).action == .startCapture)
        #expect(machine.handle(.flagsChanged([.maskControl])).action == .stopCapture)
        // The later key-up must not emit a second stop (no stop-without-start).
        #expect(machine.handle(.keyUp(6)).action == HotkeyAction.none)
    }

    @Test func comboKeyUpWithoutPriorStartEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyUp(6)).action == HotkeyAction.none)
        #expect(machine.handle(.flagsChanged([])).action == HotkeyAction.none)
    }

    // MARK: - swallow matrix (D30)

    @Test func chordDownHoldAndUpAreAllSwallowed() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate]))
            == HotkeyDecision(action: .startCapture, swallow: true))
        // Autorepeat down while capturing: no action, still swallowed.
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate]))
            == HotkeyDecision(action: .none, swallow: true))
        #expect(machine.handle(.keyUp(6))
            == HotkeyDecision(action: .stopCapture, swallow: true))
    }

    @Test func keyUpAfterModifierReleaseStopIsStillSwallowed() {
        // Pair balance (D30): capture ends via flagsChanged, but the chord
        // key's down was swallowed, so its trailing up must be too.
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).swallow)
        #expect(machine.handle(.flagsChanged([.maskControl]))
            == HotkeyDecision(action: .stopCapture, swallow: false))
        #expect(machine.handle(.keyUp(6))
            == HotkeyDecision(action: .none, swallow: true))
    }

    @Test func autorepeatAfterModifierReleaseStopIsStillSwallowed() {
        // Regression guard, D30 pair-balance invariant: while a swallowed
        // press is physically held, its autorepeats stay swallowed even
        // after a modifier release ended capture — otherwise the focused
        // app would see repeat downs whose keyUp is swallowed.
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).swallow)
        #expect(machine.handle(.flagsChanged([])).action == .stopCapture)
        #expect(machine.handle(.keyDown(6, []))
            == HotkeyDecision(action: .none, swallow: true))
        #expect(machine.handle(.keyUp(6))
            == HotkeyDecision(action: .none, swallow: true))
    }

    @Test func flagsChangedIsNeverSwallowed() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.flagsChanged([.maskControl])).swallow == false)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).swallow)
        // Even the modifier release that stops capture passes through.
        #expect(machine.handle(.flagsChanged([])).swallow == false)
    }

    @Test func otherKeycodesAreNeverSwallowed() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])).swallow)
        // Typing mid-dictation must reach the focused app.
        #expect(machine.handle(.keyDown(7, [.maskControl, .maskAlternate])).swallow == false)
        #expect(machine.handle(.keyUp(7)).swallow == false)
    }

    @Test func chordKeyTypedWithoutModifiersIsNotSwallowed() {
        // Pair balance negative case: a plain press of the chord key (no
        // modifiers) passes through in full — down and up.
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, []))
            == HotkeyDecision(action: .none, swallow: false))
        #expect(machine.handle(.keyUp(6))
            == HotkeyDecision(action: .none, swallow: false))
    }

    @Test func bareDownThenModifiersNeverStartsCaptureOrSwallows() {
        // R29 regression (D30 pair balance): the physical press began
        // unswallowed, so autorepeat downs after the modifiers arrive must
        // not start capture — the app saw the down; it must see the up.
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, []))
            == HotkeyDecision(action: .none, swallow: false))
        #expect(machine.handle(.flagsChanged([.maskControl, .maskAlternate])).swallow == false)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate]))
            == HotkeyDecision(action: .none, swallow: false))
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate]))
            == HotkeyDecision(action: .none, swallow: false))
        #expect(machine.handle(.keyUp(6))
            == HotkeyDecision(action: .none, swallow: false))
        // A fresh press with the chord held is a normal start again.
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate]))
            == HotkeyDecision(action: .startCapture, swallow: true))
    }

    @Test func fnHoldModeNeverSwallows() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)).swallow == false)
        #expect(machine.handle(.keyDown(6, .maskSecondaryFn)).swallow == false)
        #expect(machine.handle(.keyUp(6)).swallow == false)
        #expect(machine.handle(.flagsChanged([])).swallow == false)
    }

    // MARK: - parse

    @Test func parseFnIsCaseInsensitive() {
        #expect(HotkeyChord.parse("fn") == .fnHold)
        #expect(HotkeyChord.parse("FN") == .fnHold)
    }

    @Test func parseComboMapsModifiersAndKeyCode() {
        #expect(HotkeyChord.parse("ctrl+alt+z") == Self.ctrlAltZ)
        #expect(HotkeyChord.parse("CTRL+ALT+Z") == Self.ctrlAltZ)
        #expect(HotkeyChord.parse("cmd+shift+p")
            == .combo(keyCode: 35, modifiers: [.maskCommand, .maskShift]))
    }

    @Test(arguments: ["", "banana", "z", "5", "9", "ctrl+", "ctrl+banana", "banana+z", "fn+z"])
    func parseRejectsGarbage(_ input: String) {
        #expect(HotkeyChord.parse(input) == nil)
    }

    // MARK: - Phase 9: function keys, resolved default, HotkeyOption

    @Test func parseLoneFunctionKeyIsBareHold() {
        #expect(HotkeyChord.parse("f5") == .combo(keyCode: 96, modifiers: []))
        #expect(HotkeyChord.parse("F5") == .combo(keyCode: 96, modifiers: []))
        #expect(HotkeyChord.parse("f12") == .combo(keyCode: 111, modifiers: []))
    }

    @Test func parseFunctionKeyWithModifiers() {
        #expect(HotkeyChord.parse("shift+f5")
            == .combo(keyCode: 96, modifiers: [.maskShift]))
    }

    @Test(arguments: ["f0", "f13", "f"])
    func parseRejectsNonexistentFunctionKeys(_ input: String) {
        #expect(HotkeyChord.parse(input) == nil)
    }

    @Test func resolvedDefaultsToF5() {
        // D80: absent or unparseable → F5 bare hold.
        #expect(HotkeyChord.resolved(from: nil) == .combo(keyCode: 96, modifiers: []))
        #expect(HotkeyChord.resolved(from: "") == .combo(keyCode: 96, modifiers: []))
        #expect(HotkeyChord.resolved(from: "garbage") == .combo(keyCode: 96, modifiers: []))
    }

    @Test func resolvedParsesValidStrings() {
        #expect(HotkeyChord.resolved(from: "f6") == .combo(keyCode: 97, modifiers: []))
        #expect(HotkeyChord.resolved(from: "fn") == .fnHold)
        #expect(HotkeyChord.resolved(from: "ctrl+alt+z") == Self.ctrlAltZ)
    }

    @Test func hotkeyOptionRoundTrips() {
        #expect(HotkeyOption.functionKey(5).persisted == "f5")
        #expect(HotkeyOption.functionKey(5).chord == .combo(keyCode: 96, modifiers: []))
        #expect(HotkeyOption.custom("ctrl+alt+z").chord == Self.ctrlAltZ)
        #expect(HotkeyOption.from(persisted: "f5") == .functionKey(5))
        #expect(HotkeyOption.from(persisted: "F5") == .functionKey(5))
        #expect(HotkeyOption.from(persisted: nil) == .functionKey(5))
        #expect(HotkeyOption.from(persisted: "") == .functionKey(5))
        #expect(HotkeyOption.from(persisted: "ctrl+alt+z") == .custom("ctrl+alt+z"))
        #expect(HotkeyOption.from(persisted: "fn") == .custom("fn"))
    }

    @Test func hotkeyOptionInvalidCustomHasNilChord() {
        #expect(HotkeyOption.custom("banana").chord == nil)
    }

    // MARK: - Phase 9: bare-key D30 pair-balance (rides handleCombo unchanged)

    @Test func bareFunctionKeyChordSwallowsAndPairBalances() {
        var machine = HotkeyStateMachine(chord: .combo(keyCode: 96, modifiers: []))
        #expect(machine.handle(.keyDown(96, []))
            == HotkeyDecision(action: .startCapture, swallow: true))
        // Autorepeat down while held: no action, still swallowed.
        #expect(machine.handle(.keyDown(96, []))
            == HotkeyDecision(action: .none, swallow: true))
        #expect(machine.handle(.keyUp(96))
            == HotkeyDecision(action: .stopCapture, swallow: true))
    }

    @Test func bareFunctionKeyFlagsChangedNeverStops() {
        // Empty modifiers ⊆ every flags, so a modifier press/release mid-hold
        // must NOT end a bare-key capture (only keyUp does).
        var machine = HotkeyStateMachine(chord: .combo(keyCode: 96, modifiers: []))
        #expect(machine.handle(.keyDown(96, [])).action == .startCapture)
        #expect(machine.handle(.flagsChanged([.maskShift])).action == HotkeyAction.none)
        #expect(machine.handle(.flagsChanged([])).action == HotkeyAction.none)
        #expect(machine.handle(.keyUp(96)).action == .stopCapture)
    }
}
