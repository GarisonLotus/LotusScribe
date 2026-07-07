import AppKit
import os

/// Owns the single event-tap monitor and re-binds it live when the hotkey
/// setting changes (Phase 9, D84). Mirrors `EventTapMonitor`'s nonisolated,
/// app-lifetime role; `start()`/`rebind()` must be called on the main thread
/// (EventTapMonitor installs its run-loop source there). Dictation wiring is
/// untouched — the injected `onAction` is the same closure AppDelegate used to
/// hand `EventTapMonitor` directly.
final class HotkeyController {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "HotkeyController")

    private let store: SettingsStore
    private let onAction: @MainActor (HotkeyAction) -> Void
    private var monitor: EventTapMonitor?
    private var observer: NSObjectProtocol?

    init(
        store: SettingsStore = SettingsStore(),
        onAction: @escaping @MainActor (HotkeyAction) -> Void
    ) {
        self.store = store
        self.onAction = onAction
        // D84: any hotkey change reposts lotusHotkeyChanged → rebuild the tap.
        observer = NotificationCenter.default.addObserver(
            forName: .lotusHotkeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebind() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    /// Build the tap from the stored chord and start it. Call once at launch.
    func start() { rebind() }

    /// Tear down the current tap and rebuild it from the current stored chord
    /// (D84). The state machine is immutable, so a rebind is a fresh monitor.
    func rebind() {
        monitor?.stop()
        let chord = HotkeyChord.resolved(from: store.hotkeyChord)
        Self.logger.info(
            "hotkey rebind → \(String(describing: chord), privacy: .public)")
        let monitor = EventTapMonitor(chord: chord) { [weak self] action in
            Self.logger.info(
                "hotkey action: \(String(describing: action), privacy: .public)")
            // EventTapMonitor delivers on the main thread (its run-loop source).
            MainActor.assumeIsolated { self?.onAction(action) }
        }
        self.monitor = monitor
        monitor.start()
    }
}

extension Notification.Name {
    /// Posted after the persisted hotkey changes so the live tap re-binds (D84).
    static let lotusHotkeyChanged =
        Notification.Name("com.garisonlotus.LotusScribe.hotkeyChanged")

    /// Posted after each dictation terminates so observers (the onboarding
    /// try-it view) can react — userInfo["outcome"] = DictationOutcome.rawValue (D97).
    static let lotusDictationOutcome =
        Notification.Name("com.garisonlotus.LotusScribe.dictationOutcome")

    /// Posted when onboarding closes, i.e. after the user may have granted
    /// Input Monitoring. AppDelegate uses it to start the hotkey tap live once
    /// the grant lands, so a fresh user need not relaunch. The tap is NOT
    /// created at launch for an ungranted user — that would prompt for
    /// Accessibility and dirty the AX subsystem (rdar://7381305).
    static let lotusPermissionsChanged =
        Notification.Name("com.garisonlotus.LotusScribe.permissionsChanged")
}

/// The single write path for the hotkey setting, used by both UI surfaces
/// (D83/D84): persist the choice, then post the live re-bind ping. Defaults
/// stay the single source of truth — the notification is a bare "changed" ping.
enum HotkeySetting {
    static func set(_ option: HotkeyOption, store: SettingsStore = SettingsStore()) {
        store.hotkeyChord = option.persisted
        NotificationCenter.default.post(name: .lotusHotkeyChanged, object: nil)
    }
}
