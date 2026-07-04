import CoreGraphics
import Foundation
import os

/// TCC-bearing adapter around a listen-only session CGEventTap (D16). Maps
/// keyboard CGEvents to HotkeyEvents, feeds HotkeyStateMachine, and forwards
/// its non-`.none` actions to `onAction` on the main thread. No decision
/// logic here (D14) — that lives in HotkeyStateMachine.
///
/// Degrades gracefully: if tap creation fails (listen access not granted —
/// e.g. the hosted-test app or a headless launch), it logs and the app keeps
/// running without a hotkey ("functional when permissions denied" invariant).
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
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // D16 — never blocks or modifies events
            eventsOfInterest: mask,
            callback: EventTapMonitor.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
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
        EventTapMonitor.logger.info("event tap started")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    /// C-convention trampoline; refcon is the unretained monitor.
    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        if let refcon {
            Unmanaged<EventTapMonitor>.fromOpaque(refcon).takeUnretainedValue()
                .handleTapEvent(type: type, event: event)
        }
        // Listen-only tap: return value is ignored, but pass the event
        // through unmodified anyway (D16).
        return Unmanaged.passUnretained(event)
    }

    private func handleTapEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout:
            // The system disables slow taps; re-enable so the hotkey survives.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            forward(.flagsChanged(event.flags))
        case .keyDown:
            forward(.keyDown(event.getIntegerValueField(.keyboardEventKeycode), event.flags))
        case .keyUp:
            forward(.keyUp(event.getIntegerValueField(.keyboardEventKeycode)))
        default:
            break
        }
    }

    private func forward(_ event: HotkeyEvent) {
        let action = machine.handle(event)
        guard action != HotkeyAction.none else { return }
        onAction(action)  // already on the main thread — see start()
    }
}
