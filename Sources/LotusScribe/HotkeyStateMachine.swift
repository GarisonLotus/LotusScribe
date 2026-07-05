import CoreGraphics

// Pure hotkey logic — no TCC, 100% unit-tested (D14).
// See docs/phase-1-spec.md §"Sub-phase 1A".

/// The configured push-to-talk trigger. Parsed from the `hotkeyChord`
/// defaults key (D15); nil/unparseable falls back to `.fnHold` at the call site.
enum HotkeyChord: Equatable {
    case fnHold
    case combo(keyCode: Int64, modifiers: CGEventFlags)

    /// Parses "fn" or "<modifier>+…+<key>" (e.g. "ctrl+alt+z"), case-insensitive.
    /// Combos need at least one modifier; anything else returns nil.
    static func parse(_ string: String) -> HotkeyChord? {
        let tokens = string.lowercased().split(separator: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        if tokens == ["fn"] { return .fnHold }
        guard tokens.count >= 2, let key = tokens.last, let keyCode = keyCodes[key] else {
            return nil
        }
        var modifiers: CGEventFlags = []
        for token in tokens.dropLast() {
            guard let flag = modifierFlags[token] else { return nil }
            modifiers.insert(flag)
        }
        return .combo(keyCode: keyCode, modifiers: modifiers)
    }

    private static let modifierFlags: [String: CGEventFlags] = [
        "ctrl": .maskControl, "control": .maskControl,
        "alt": .maskAlternate, "option": .maskAlternate, "opt": .maskAlternate,
        "cmd": .maskCommand, "command": .maskCommand,
        "shift": .maskShift,
    ]

    /// ANSI-layout virtual key codes (HIToolbox kVK_ANSI_*), letters + digits.
    private static let keyCodes: [String: Int64] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8,
        "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45,
        "m": 46, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
        "8": 28, "9": 25, "0": 29,
    ]
}

/// Keyboard activity relevant to the hotkey, mapped from CGEvents by EventTapMonitor.
enum HotkeyEvent {
    case flagsChanged(CGEventFlags)
    case keyDown(Int64, CGEventFlags)
    case keyUp(Int64)
}

/// What the machine's owner should do in response to an event.
enum HotkeyAction { case startCapture, stopCapture, none }

/// Action plus whether the event tap should consume the event (D30).
/// Swallowing only ever applies to the chord keycode's keyDown/keyUp in
/// combo mode — never flagsChanged, never other keys, never `.fnHold`.
struct HotkeyDecision: Equatable {
    var action: HotkeyAction
    var swallow: Bool
}

/// Tracks whether the chord is held. Invariant (spec §1A): never emits
/// `.stopCapture` without a prior `.startCapture`; duplicate downs and
/// repeated same-state flags are `.none`. D30 invariant: down/up swallowing
/// is pair-balanced — a chord keyUp is swallowed iff its keyDown was, so no
/// app ever sees half of the chord key's down/up pair.
struct HotkeyStateMachine {
    private let chord: HotkeyChord
    private var isCapturing = false
    // D30 pair balance: true while a swallowed chord-key press is still
    // physically held (survives the modifier-release stop path, where
    // isCapturing goes false before the trailing keyUp arrives).
    private var chordKeyDownSwallowed = false
    // R29: true while a chord-key press that passed through unswallowed is
    // physically held — later autorepeats (even with modifiers now present)
    // must not start capture, or the eventual keyUp would be swallowed
    // unbalanced. Cleared on keyUp (fresh press required).
    private var chordKeyDownPassedThrough = false

    init(chord: HotkeyChord) {
        self.chord = chord
    }

    mutating func handle(_ event: HotkeyEvent) -> HotkeyDecision {
        switch chord {
        case .fnHold:
            // D30: fnHold is driven by flagsChanged only — never swallow.
            return HotkeyDecision(action: handleFnHold(event), swallow: false)
        case .combo(let keyCode, let modifiers):
            return handleCombo(event, keyCode: keyCode, modifiers: modifiers)
        }
    }

    private mutating func handleFnHold(_ event: HotkeyEvent) -> HotkeyAction {
        guard case .flagsChanged(let flags) = event else { return .none }
        switch (flags.contains(.maskSecondaryFn), isCapturing) {
        case (true, false):
            isCapturing = true
            return .startCapture
        case (false, true):
            isCapturing = false
            return .stopCapture
        default:
            return .none
        }
    }

    private mutating func handleCombo(
        _ event: HotkeyEvent, keyCode: Int64, modifiers: CGEventFlags
    ) -> HotkeyDecision {
        switch event {
        case .keyDown(let code, let flags):
            guard code == keyCode else {
                return HotkeyDecision(action: .none, swallow: false)
            }
            if chordKeyDownSwallowed {
                // Autorepeat of a swallowed press — while capturing, or held
                // past a modifier-release stop. Swallowed either way so the
                // focused app never sees a down whose up will be swallowed.
                return HotkeyDecision(action: .none, swallow: true)
            }
            // isSuperset: real events carry extra flag bits (device-dependent,
            // non-coalesced); only the chord's modifiers must be present.
            guard !isCapturing, !chordKeyDownPassedThrough,
                  flags.isSuperset(of: modifiers) else {
                chordKeyDownPassedThrough = true
                return HotkeyDecision(action: .none, swallow: false)
            }
            isCapturing = true
            chordKeyDownSwallowed = true
            return HotkeyDecision(action: .startCapture, swallow: true)
        case .keyUp(let code):
            guard code == keyCode else {
                return HotkeyDecision(action: .none, swallow: false)
            }
            // Pair balance (D30): swallow iff the matching down was swallowed.
            let swallow = chordKeyDownSwallowed
            chordKeyDownSwallowed = false
            chordKeyDownPassedThrough = false
            guard isCapturing else {
                return HotkeyDecision(action: .none, swallow: swallow)
            }
            isCapturing = false
            return HotkeyDecision(action: .stopCapture, swallow: swallow)
        case .flagsChanged(let flags):
            // Releasing any required modifier mid-hold also ends capture.
            // Never swallowed — modifiers are shared system state (D30).
            guard isCapturing, !flags.isSuperset(of: modifiers) else {
                return HotkeyDecision(action: .none, swallow: false)
            }
            isCapturing = false
            return HotkeyDecision(action: .stopCapture, swallow: false)
        }
    }
}
