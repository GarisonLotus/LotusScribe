import AppKit
import os

/// TCC-bearing adapter (spec §1D): lands text in the focused app by writing
/// it to the general pasteboard and synthesizing Cmd-V.
///
/// Invariant (§1D): insertion is write + paste ONLY — zero pasteboard reads
/// anywhere in the app. No clipboard save/restore (D20 — restore requires a
/// pasteboard read, deferred to Phase 6); clobbering is accepted Phase-1
/// behavior.
@MainActor
struct TextInserter {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "TextInserter")

    /// ANSI-layout virtual key code for "V".
    private static let vKeyCode: CGKeyCode = 9

    func insert(_ text: String) {
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
