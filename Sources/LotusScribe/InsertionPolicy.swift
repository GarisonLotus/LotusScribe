import Foundation

/// Which landing path an insertion takes (spec §6B, D61/D65).
enum InsertionRoute: Equatable {
    case ax
    case pasteboard
}

/// Pure routing decision for text insertion (spec §6B, D61/D65). The AX
/// probe results arrive as booleans — the AX calls themselves stay
/// adapter-side in TextInserter (D49/D52 no-seam posture) — so this file
/// is Foundation-only and the truth table is headless (D65: policy in one
/// file, exactly the CleanupLevel/AppCategory proven shape).
enum InsertionPolicy {
    /// AX only when the focused element was found AND reports
    /// kAXSelectedText settable (D61); anything less → pasteboard.
    /// Settable-selected-text is the one probe that means "this element
    /// accepts programmatic text replacement" — Electron/Chromium elements
    /// typically fail it, giving the PLAN-required natural fallback.
    static func route(
        focusedElementFound: Bool, selectedTextSettable: Bool
    ) -> InsertionRoute {
        focusedElementFound && selectedTextSettable ? .ax : .pasteboard
    }
}
