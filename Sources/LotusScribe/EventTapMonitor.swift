import CoreGraphics
import Foundation
import os

/// TCC-bearing adapter around a session CGEventTap. Maps keyboard CGEvents
/// to HotkeyEvents, feeds HotkeyStateMachine, and forwards its non-`.none`
/// actions to `onAction` on the main thread. No decision logic here (D14) —
/// that lives in HotkeyStateMachine.
///
/// D30: the tap is `.defaultTap` so the chord keycode's keyDown/keyUp can be
/// consumed (callback returns nil when the machine says swallow). If
/// `.defaultTap` creation fails, retries `.listenOnly` — Phase-1 chord
/// leakage beats a dead hotkey.
///
/// Degrades gracefully: if tap creation fails entirely (listen access not
/// granted — e.g. the hosted-test app or a headless launch), it logs and the
/// app keeps running without a hotkey ("functional when permissions denied"
/// invariant).
final class EventTapMonitor {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "EventTapMonitor")

    private var machine: HotkeyStateMachine
    private let onAction: (HotkeyAction) -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(chord: HotkeyChord, onAction: @escaping (HotkeyAction) -> Void) {
        self.machine = HotkeyStateMachine(chord: chord)
        self.onAction = onAction
    }

    deinit {
        stop()
    }

    func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue)
                | (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue))
        // D30: .defaultTap so swallow decisions can consume the chord key.
        var mode = "defaultTap"
        var created = createTap(options: .defaultTap, mask: mask)
        if created == nil {
            mode = "listenOnly"
            created = createTap(options: .listenOnly, mask: mask)
            if created != nil {
                EventTapMonitor.logger.error(
                    ".defaultTap creation failed — fell back to .listenOnly (D30); chord key will leak to the focused app")
            }
        }
        guard let tap = created else {
            EventTapMonitor.logger.error(
                "event tap creation failed — listen access not granted (Input Monitoring or Accessibility in System Settings); hotkey disabled, app otherwise functional")
            return
        }
        self.tap = tap
        // Source goes on the MAIN run loop, so the tap callback — and
        // therefore onAction — always runs on the main thread.
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        // Mode is part of the Q5 empirical record — keep it in the log line.
        EventTapMonitor.logger.info("event tap started (\(mode, privacy: .public))")
    }

    private func createTap(options: CGEventTapOptions, mask: CGEventMask) -> CFMachPort? {
        CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: mask,
            callback: EventTapMonitor.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// C-convention trampoline; refcon is the unretained monitor. Returning
    /// nil consumes the event (D30 swallow); anything else passes through
    /// unmodified. (Under the .listenOnly fallback the return is ignored.)
    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let swallow = Unmanaged<EventTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
            .handleTapEvent(type: type, event: event)
        return swallow ? nil : Unmanaged.passUnretained(event)
    }

    /// Returns true when the event must be swallowed (chord keyDown/keyUp
    /// only — the machine never swallows anything else, D30).
    private func handleTapEvent(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables slow taps (timeout) or a user/system action
            // disables it directly; re-enable either way so the hotkey
            // survives (D49 — a dead tap is a silently dead hotkey).
            EventTapMonitor.logger.info(
                "tap disabled (\(type == .tapDisabledByTimeout ? "timeout" : "userInput", privacy: .public)) — re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .flagsChanged:
            return forward(.flagsChanged(event.flags))
        case .keyDown:
            return forward(.keyDown(event.getIntegerValueField(.keyboardEventKeycode), event.flags))
        case .keyUp:
            return forward(.keyUp(event.getIntegerValueField(.keyboardEventKeycode)))
        default:
            return false
        }
    }

    private func forward(_ event: HotkeyEvent) -> Bool {
        let decision = machine.handle(event)
        if decision.action != HotkeyAction.none {
            onAction(decision.action)  // already on the main thread — see start()
        }
        return decision.swallow
    }
}
