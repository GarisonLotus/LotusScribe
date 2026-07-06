import AppKit
import ApplicationServices
import os

/// TCC-bearing adapter (spec §1D, §6B): lands text in the focused app.
/// Route-then-land (D61): probe the focused AX element; when it reports
/// kAXSelectedText settable, replace the selection in place; anything
/// less — or any AX failure mid-flight — lands via the Phase-1 pasteboard
/// write + synthesized Cmd-V (D43 chain: no path discards text).
///
/// Invariant (§1D, §6B): the pasteboard route is byte-identical to
/// Phase 1 — write + paste ONLY, zero pasteboard reads anywhere in the
/// app. No clipboard save/restore yet (D20/D62 — that is 6C); clobbering
/// is still accepted behavior. AX calls stay adapter-side direct (D49
/// no-seam posture); the route decision itself is pure (InsertionPolicy).
@MainActor
struct TextInserter {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "TextInserter")

    /// ANSI-layout virtual key code for "V".
    private static let vKeyCode: CGKeyCode = 9

    func insert(_ text: String) {
        let probe = Self.probeFocusedElement()
        let route = InsertionPolicy.route(
            focusedElementFound: probe.element != nil,
            selectedTextSettable: probe.selectedTextSettable)

        // One route log per insertion (D65) — the 6B batch matrix reads
        // these from Console instead of guessing.
        if route == .ax, let element = probe.element {
            let status = AXUIElementSetAttributeValue(
                element, kAXSelectedTextAttribute as CFString, text as CFString)
            if status == .success {
                Self.logger.info("insertion route: ax")
                return
            }
            // D43 chain: ANY non-success falls through to the pasteboard
            // route in the SAME call — AX failure never loses the text.
            Self.logger.info(
                "insertion route: ax-fallback (AX set error \(status.rawValue))")
        } else {
            Self.logger.info("insertion route: pasteboard")
        }
        landViaPasteboard(text)
    }

    /// D61 probe: system-wide focused element, then kAXSelectedText
    /// settability. "Found" = `.success` + a non-nil AXUIElement;
    /// "settable" = `.success` && true. The 0.25 s messaging timeout
    /// bounds a beachballing target so insertion cannot stall for seconds.
    private static func probeFocusedElement()
        -> (element: AXUIElement?, selectedTextSettable: Bool)
    {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.25)

        var focusedRef: CFTypeRef?
        let copyStatus = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard copyStatus == .success, let focusedRef,
            CFGetTypeID(focusedRef) == AXUIElementGetTypeID()
        else {
            return (nil, false)
        }
        let focused = focusedRef as! AXUIElement

        var settable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            focused, kAXSelectedTextAttribute as CFString, &settable)
        return (focused, settableStatus == .success && settable.boolValue)
    }

    /// Phase-1 pasteboard route, byte-identical: write, then synthesize
    /// Cmd-V. Write precedes synthesis so a CGEvent failure still leaves
    /// the text on the board as the last-resort landing spot (D43).
    private func landViaPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: true),
            let keyUp = CGEvent(
                keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: false)
        else {
            // Failure policy (spec §cross-cutting): log, do nothing.
            Self.logger.error("CGEvent creation failed — paste not synthesized")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
