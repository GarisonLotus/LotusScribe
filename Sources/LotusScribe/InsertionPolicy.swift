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
    /// D75: bundles whose AX reports kAXSelectedText settable AND returns
    /// .success on set WITHOUT inserting (silent AX failure). Evidence-gated:
    /// add a bundle only on a confirmed live silent failure, never
    /// prophylactically — over-blocking costs AX-route quality (no clipboard
    /// traffic) in apps where AX is honest.
    static let axDenylist: Set<String> = ["com.tinyspeck.slackmacgap"]

    /// AX only when the focused element was found AND reports
    /// kAXSelectedText settable (D61); anything less → pasteboard.
    /// Settable-selected-text is the one probe that means "this element
    /// accepts programmatic text replacement" — Electron/Chromium elements
    /// typically fail it, giving the PLAN-required natural fallback.
    /// D75: a denylisted target bundle forces pasteboard regardless of the
    /// probe (its AX lies about success); nil bundle → D61 table unchanged.
    static func route(
        targetBundleID: String?, focusedElementFound: Bool,
        selectedTextSettable: Bool
    ) -> InsertionRoute {
        if let targetBundleID, axDenylist.contains(targetBundleID) {
            return .pasteboard
        }
        return focusedElementFound && selectedTextSettable ? .ax : .pasteboard
    }
}

/// Foundation-only mirror of NSPasteboard.AccessBehavior (macOS 15.4);
/// .unavailable = pre-15.4 API absent (no enforcement exists there).
/// `.standard` mirrors AppKit's `.default` — renamed because `default`
/// is a Swift keyword (spec §6C, D62).
enum PasteboardAccessGate: Equatable {
    case unavailable, standard, ask, alwaysAllow, alwaysDeny
}

extension InsertionPolicy {
    /// Save+restore only when reading cannot prompt or fail (D62):
    /// unavailable/standard/alwaysAllow → true; ask/alwaysDeny → false.
    /// A read under `.ask` fires the system alert mid-dictation while a
    /// synthesized Cmd-V is in flight — the alert steals focus and the
    /// paste lands in the dialog (a D43 violation). Skipping there is the
    /// shipped-and-accepted Phase-1 clobber behavior.
    static func shouldSaveClipboard(gate: PasteboardAccessGate) -> Bool {
        switch gate {
        case .unavailable, .standard, .alwaysAllow: return true
        case .ask, .alwaysDeny: return false
        }
    }

    /// Restore only if nothing else wrote since our write (D62): requires
    /// a snapshot AND the live changeCount still equal to the one recorded
    /// at write time — any other writer (user copy, clipboard manager, a
    /// newer dictation) wins.
    static func shouldRestore(
        hasSnapshot: Bool, writtenChangeCount: Int, currentChangeCount: Int
    ) -> Bool {
        hasSnapshot && writtenChangeCount == currentChangeCount
    }
}
