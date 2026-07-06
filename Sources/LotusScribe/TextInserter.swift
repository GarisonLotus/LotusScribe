import AppKit
import ApplicationServices
import os

/// TCC-bearing adapter (spec §1D, §6B): lands text in the focused app.
/// Route-then-land (D61): probe the focused AX element; when it reports
/// kAXSelectedText settable, replace the selection in place; anything
/// less — or any AX failure mid-flight — lands via the Phase-1 pasteboard
/// write + synthesized Cmd-V (D43 chain: no path discards text).
///
/// Invariant (§1D as amended by D62, §6C): pasteboard reads are confined
/// to this file's gated save/restore path — nowhere else in the app. The
/// AX route does zero pasteboard traffic. Write → Cmd-V ordering is
/// unchanged (text on board before synthesis, D43 last resort); the
/// save/restore around it is gated on `PasteboardAccessGate` and a
/// changeCount guard so restore can never clobber a newer write.
@MainActor
struct TextInserter {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "TextInserter")

    /// ANSI-layout virtual key code for "V".
    private static let vKeyCode: CGKeyCode = 9

    /// Delay before clipboard restore (D62, single site): ≈5× the observed
    /// synthesized-paste handling time. Errs long — restoring before the
    /// target app reads the pasteboard would paste the OLD clipboard (a
    /// D43 violation, worse than clobbering).
    static let restoreDelay: TimeInterval = 0.5

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

    /// D62 gate mapping: NSPasteboard.AccessBehavior → pure gate. Pre-15.4
    /// the API is absent and no enforcement exists → `.unavailable`.
    /// @unknown future case → `.ask` (conservative: skip save/restore, the
    /// shipped Phase-1 clobber path — never risk a mid-dictation alert).
    private static func currentAccessGate() -> PasteboardAccessGate {
        if #available(macOS 15.4, *) {
            switch NSPasteboard.general.accessBehavior {
            case .default: return .standard
            case .ask: return .ask
            case .alwaysAllow: return .alwaysAllow
            case .alwaysDeny: return .alwaysDeny
            @unknown default: return .ask
            }
        } else {
            return .unavailable
        }
    }

    /// D62 snapshot: ALL items × types × data — images/files included
    /// (PLAN says clipboard CONTENTS survive, not just strings). An empty
    /// board snapshots as [] so restore clears back to empty.
    private static func snapshotPasteboard(_ pasteboard: NSPasteboard)
        -> [[NSPasteboard.PasteboardType: Data]]
    {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [:]) { snapshot, type in
                snapshot[type] = item.data(forType: type)
            }
        }
    }

    /// Phase-1 pasteboard route (write, then synthesize Cmd-V), now
    /// wrapped in the D62 gated save/restore. Write precedes synthesis so
    /// a CGEvent failure still leaves the text on the board as the
    /// last-resort landing spot (D43).
    private func landViaPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        let gate = Self.currentAccessGate()
        var snapshot: [[NSPasteboard.PasteboardType: Data]]?
        if InsertionPolicy.shouldSaveClipboard(gate: gate) {
            snapshot = Self.snapshotPasteboard(pasteboard)
            Self.logger.info(
                "clipboard saved (\(snapshot?.count ?? 0) item(s), gate \(String(describing: gate)))")
        } else {
            Self.logger.info(
                "clipboard save skipped (gate \(String(describing: gate)) — Phase-1 clobber, D62)")
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writtenChangeCount = pasteboard.changeCount

        guard
            let keyDown = CGEvent(
                keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: true),
            let keyUp = CGEvent(
                keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: false)
        else {
            // Failure policy (spec §cross-cutting): log, do nothing. NO
            // restore scheduled — the board carries the dictated text as
            // the D43 last-resort landing spot; restoring the snapshot
            // over it would discard the user's words.
            Self.logger.error("CGEvent creation failed — paste not synthesized")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        // Restore only after synthesis actually happened (D43): scheduled
        // here, not at write time, so the CGEvent-failure path above never
        // clobbers the last-resort text.
        scheduleRestore(snapshot: snapshot, writtenChangeCount: writtenChangeCount)
    }

    /// D62 delayed restore: after `restoreDelay`, restore the snapshot
    /// ONLY if the LIVE changeCount still equals the one we recorded at
    /// write time — any other writer (user copy, clipboard manager, a
    /// newer dictation's own write) wins and restore is skipped. A skipped
    /// restore is silent-but-logged (D38 — no pill/alert surface).
    private func scheduleRestore(
        snapshot: [[NSPasteboard.PasteboardType: Data]]?, writtenChangeCount: Int
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
            let pasteboard = NSPasteboard.general
            guard
                InsertionPolicy.shouldRestore(
                    hasSnapshot: snapshot != nil,
                    writtenChangeCount: writtenChangeCount,
                    currentChangeCount: pasteboard.changeCount),
                let snapshot
            else {
                let reason =
                    snapshot == nil
                    ? "gate skipped save" : "changeCount moved (newer write wins)"
                Self.logger.info("clipboard restore skipped (\(reason))")
                return
            }

            // Empty snapshot restores an empty board: clearContents IS the
            // restore (D62 — empty board snapshots as []).
            pasteboard.clearContents()
            let items = snapshot.map { itemData -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in itemData { item.setData(data, forType: type) }
                return item
            }
            if !items.isEmpty { pasteboard.writeObjects(items) }
            Self.logger.info("clipboard restored (\(items.count) item(s))")
        }
    }
}
