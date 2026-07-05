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

    @Test(arguments: ["", "banana", "z", "ctrl+", "ctrl+banana", "banana+z", "fn+z"])
    func parseRejectsGarbage(_ input: String) {
        #expect(HotkeyChord.parse(input) == nil)
    }
}
