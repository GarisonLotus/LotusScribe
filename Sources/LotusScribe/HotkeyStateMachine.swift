import CoreGraphics

// Pure hotkey logic — no TCC, 100% unit-tested (D14).
// See docs/phase-1-spec.md §"Sub-phase 1A".

/// The configured push-to-talk trigger. Parsed from the `hotkeyChord`
/// defaults key (D15); nil/unparseable falls back to `.fnHold` at the call site.
enum HotkeyChord: Equatable {
    case fnHold
    case combo(keyCode: Int64, modifiers: CGEventFlags)

    /// Parses "fn", a lone function key ("f5"), or "<modifier>+…+<key>"
    /// (e.g. "ctrl+alt+z"), case-insensitive. A single non-function-key token
    /// (bare letter/digit) is rejected — it would swallow that key globally
    /// (D82). Function keys may be bare (D81: the combo path swallows the whole
    /// press, so it can't leak) or modified.
    static func parse(_ string: String) -> HotkeyChord? {
        let tokens = string.lowercased().split(separator: "+").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        if tokens == ["fn"] { return .fnHold }
        // D81/D82: a lone function key is a bare hold — no modifier required.
        if tokens.count == 1, let keyCode = functionKeyCodes[tokens[0]] {
            return .combo(keyCode: keyCode, modifiers: [])
        }
        guard tokens.count >= 2, let key = tokens.last,
              let keyCode = keyCodes[key] ?? functionKeyCodes[key] else {
            return nil
        }
        var modifiers: CGEventFlags = []
        for token in tokens.dropLast() {
            guard let flag = modifierFlags[token] else { return nil }
            modifiers.insert(flag)
        }
        return .combo(keyCode: keyCode, modifiers: modifiers)
    }

    /// The persisted `hotkeyChord` string, or the ⌘⌥D default (D106) when it is
    /// absent or unparseable. Pure — the single fallback site (replaces
    /// AppDelegate's inline `?? .fnHold`; D15/D27: fn is dead on macOS 26).
    /// D106 (supersedes D105): default is ⌘⌥D — F5 (even ⌘F5) is fully claimed
    /// by macOS accessibility shortcuts, so keycode 96 never reaches the tap;
    /// ⌘⌥D is unclaimed and reaches the session tap reliably.
    static func resolved(from string: String?) -> HotkeyChord {
        string.flatMap(parse) ?? .combo(keyCode: 2, modifiers: [.maskCommand, .maskAlternate])
    }

    /// Human-readable spelling for UI labels (D89): words joined by " + ",
    /// e.g. "Command + F5" — not glyphs. Modifiers in canonical order
    /// Control, Option, Shift, Command, then the key. Pure (D14).
    var spelledLabel: String {
        switch self {
        case .fnHold:
            return "fn"
        case .combo(let keyCode, let modifiers):
            let ordered: [(CGEventFlags, String)] = [
                (.maskControl, "Control"), (.maskAlternate, "Option"),
                (.maskShift, "Shift"), (.maskCommand, "Command"),
            ]
            let parts = ordered.filter { modifiers.contains($0.0) }.map(\.1)
                + [Self.keyName(for: keyCode)]
            return parts.joined(separator: " + ")
        }
    }

    /// True when the chord's key is F5 (keycode 96) — macOS's mic/dictation
    /// key, held via Command in the default (D103). Drives the F5-specific
    /// Try-it why-line; modifiers are irrelevant (both ⌘F5 and bare F5 qualify).
    /// Pure (D14).
    var usesMicKey: Bool {
        if case .combo(96, _) = self { return true }
        return false
    }

    /// Reverse of `functionKeyCodes`/`keyCodes` — the display name for a
    /// keycode ("f5" → "F5", "z" → "Z"); unknown → "key<code>".
    private static func keyName(for code: Int64) -> String {
        if let name = functionKeyCodes.first(where: { $0.value == code })?.key {
            return name.uppercased()
        }
        if let name = keyCodes.first(where: { $0.value == code })?.key {
            return name.uppercased()
        }
        return "key\(code)"
    }

    private static let modifierFlags: [String: CGEventFlags] = [
        "ctrl": .maskControl, "control": .maskControl,
        "alt": .maskAlternate, "option": .maskAlternate, "opt": .maskAlternate,
        "cmd": .maskCommand, "command": .maskCommand,
        "shift": .maskShift,
    ]

    /// HIToolbox kVK_F1…F12. Positional like `keyCodes` (R7 caveat): "f5" is
    /// the physical F5 key — the mac dictation/mic key; the Phase 9 default
    /// pairs it with Command (D87) since bare F5 is consumed by the system.
    private static let functionKeyCodes: [String: Int64] = [
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
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

/// UI ⇄ persistence bridge for the Phase 9 hotkey picker. Pure/headless (D14):
/// maps a picker selection to the `hotkeyChord` string and back. The two UI
/// surfaces (onboarding, settings) speak only in `HotkeyOption`.
enum HotkeyOption: Equatable {
    /// A bare function-key hold, F1…F12.
    case functionKey(Int)
    /// A raw combo string (e.g. "ctrl+alt+cmd+9") or the "fn" escape hatch.
    case custom(String)

    /// The string written to `hotkeyChord`.
    var persisted: String {
        switch self {
        case .functionKey(let n): return "f\(n)"
        case .custom(let s): return s
        }
    }

    /// The chord this option resolves to, or nil if a custom string is invalid.
    var chord: HotkeyChord? { HotkeyChord.parse(persisted) }

    /// Reconstruct the option from a persisted string. "f1"…"f12" → function
    /// key; absent/empty → the ⌃⌥D default (D105); everything else (combos,
    /// "fn") → custom, original casing preserved for display.
    static func from(persisted: String?) -> HotkeyOption {
        guard let lowered = persisted?.lowercased(), !lowered.isEmpty else {
            return .custom("command+option+d")
        }
        if lowered.first == "f", let n = Int(lowered.dropFirst()), (1...12).contains(n) {
            return .functionKey(n)
        }
        return .custom(persisted!)
    }
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
