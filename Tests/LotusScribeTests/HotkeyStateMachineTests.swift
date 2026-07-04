import CoreGraphics
import Testing
@testable import LotusScribe

/// Unit tests for the pure 1A hotkey logic (spec §1A invariant: hotkey logic
/// is 100% unit-tested pure code). Comparisons use `HotkeyAction.none`
/// spelled out to avoid any reading ambiguity with `Optional.none`.
struct HotkeyStateMachineTests {
    /// ctrl+alt+z — kVK_ANSI_Z is 6.
    private static let ctrlAltZ = HotkeyChord.combo(
        keyCode: 6, modifiers: [.maskControl, .maskAlternate])

    // MARK: - fnHold

    @Test func fnPressStartsAndReleaseStopsAcrossCycles() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)) == .startCapture)
        #expect(machine.handle(.flagsChanged([])) == .stopCapture)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)) == .startCapture)
        #expect(machine.handle(.flagsChanged([])) == .stopCapture)
    }

    @Test func repeatedFlagsChangedInSameStateIsIdempotent() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)) == .startCapture)
        #expect(machine.handle(.flagsChanged(.maskSecondaryFn)) == HotkeyAction.none)
        #expect(machine.handle(.flagsChanged([])) == .stopCapture)
        #expect(machine.handle(.flagsChanged([])) == HotkeyAction.none)
    }

    @Test func fnReleaseWithoutPriorPressEmitsNothing() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.flagsChanged([])) == HotkeyAction.none)
    }

    @Test func fnHoldIgnoresKeyDownAndKeyUp() {
        var machine = HotkeyStateMachine(chord: .fnHold)
        #expect(machine.handle(.keyDown(6, [.maskControl])) == HotkeyAction.none)
        #expect(machine.handle(.keyUp(6)) == HotkeyAction.none)
    }

    // MARK: - combo

    @Test func comboKeyDownStartsAndKeyUpStops() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])) == .startCapture)
        #expect(machine.handle(.keyUp(6)) == .stopCapture)
    }

    @Test func comboMatchesWithExtraFlagBitsPresent() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        let realWorldFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskNonCoalesced]
        #expect(machine.handle(.keyDown(6, realWorldFlags)) == .startCapture)
    }

    @Test func nonMatchingKeyCodeEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(7, [.maskControl, .maskAlternate])) == HotkeyAction.none)
    }

    @Test func missingRequiredModifierEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl])) == HotkeyAction.none)
    }

    @Test func duplicateKeyDownWhileCapturingEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])) == .startCapture)
        // OS key-repeat delivers duplicate downs while held.
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])) == HotkeyAction.none)
        #expect(machine.handle(.keyUp(6)) == .stopCapture)
    }

    @Test func modifierReleaseWhileCapturingStops() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyDown(6, [.maskControl, .maskAlternate])) == .startCapture)
        #expect(machine.handle(.flagsChanged([.maskControl])) == .stopCapture)
        // The later key-up must not emit a second stop (no stop-without-start).
        #expect(machine.handle(.keyUp(6)) == HotkeyAction.none)
    }

    @Test func comboKeyUpWithoutPriorStartEmitsNothing() {
        var machine = HotkeyStateMachine(chord: Self.ctrlAltZ)
        #expect(machine.handle(.keyUp(6)) == HotkeyAction.none)
        #expect(machine.handle(.flagsChanged([])) == HotkeyAction.none)
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
