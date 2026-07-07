import AppKit
import SwiftUI
import os

/// Owns the NSStatusItem: a full-color lotus mark (never a template — spec
/// Task 2) whose three states track dictation, plus a menu with Settings…,
/// Rerun Onboarding…, and Quit. NSObject subclass so it can be an NSMenuItem
/// action target.
@MainActor
final class StatusItemController: NSObject {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "StatusItemController")
    private let statusItem: NSStatusItem
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?

    /// Current capture phase driving the icon (idle / listening / processing).
    private var state: DictationController.CaptureState = .idle
    /// Drives the processing dot's pulse; nil unless processing + motion allowed.
    private var pulseTimer: Timer?
    /// Monotonic step counter for the pulse waveform.
    private var pulseStep = 0

    override init() {
        // variableLength: the item widens for the activity dot in the
        // listening/processing states and shrinks back to the bare mark idle.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        renderIcon()

        let menu = NSMenu()
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        let onboardingItem = NSMenuItem(
            title: "Rerun Onboarding…",
            action: #selector(openOnboarding),
            keyEquivalent: ""
        )
        onboardingItem.target = self
        menu.addItem(onboardingItem)
        menu.addItem(NSMenuItem(
            title: "Quit LotusScribe",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // Lazy: the window is only built on first open; kept so reopening focuses it.
    @objc private func openSettings() {
        Self.logger.info("openSettings fired")
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    // 7B (D67): reopens regardless of the onboardingCompleted flag —
    // same lazy caching idiom as openSettings. Sole creation site for
    // OnboardingWindowController (R67): AppDelegate's launch hook calls
    // showOnboarding() so "Rerun Onboarding…" can never race a second
    // window against the launch-shown one.
    @objc private func openOnboarding() {
        showOnboarding()
    }

    func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
        }
        onboardingWindowController?.show()
    }

    /// Set the capture phase (from DictationController via AppDelegate) and
    /// re-render. Manages the processing-dot pulse: a smooth 900 ms opacity
    /// loop, or — under Reduce Motion — a two-frame bright/dim swap instead of
    /// a smooth animation (spec Task 2).
    func setState(_ newState: DictationController.CaptureState) {
        guard newState != state else { return }
        state = newState
        stopPulse()
        if state == .processing {
            pulseStep = 0
            // Reduce Motion → slow two-frame swap; else a smoother step loop.
            let interval = Self.reduceMotion ? 0.45 : 0.06
            pulseTimer = Timer.scheduledTimer(
                withTimeInterval: interval, repeats: true
            ) { [weak self] _ in
                // The timer fires on the main run loop, so assume the actor
                // (same idiom as DictationController's level callback).
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pulseStep += 1
                    self.renderIcon()
                }
            }
        }
        renderIcon()
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
    }

    private static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// The processing dot's current opacity: a smooth 1 → 0.25 → 1 cosine over
    /// ~900 ms (15 × 60 ms steps), or a discrete bright/dim toggle under Reduce
    /// Motion (two static frames, no smooth motion). Full opacity otherwise.
    private var dotOpacity: Double {
        guard state == .processing else { return 1 }
        if Self.reduceMotion {
            return pulseStep.isMultiple(of: 2) ? 1 : 0.25
        }
        let t = Double(pulseStep % 15) / 15
        return 0.25 + 0.75 * (0.5 + 0.5 * cos(t * 2 * .pi))
    }

    /// Snapshot the SwiftUI icon into a NON-template (colorful) NSImage and set
    /// it on the button. `isTemplate = false` keeps the lotus in full color —
    /// the menu bar must never tint it monochrome (spec Task 2).
    private func renderIcon() {
        let renderer = ImageRenderer(
            content: StatusIcon(state: state, dotOpacity: dotOpacity))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return }
        image.isTemplate = false
        statusItem.button?.image = image
    }
}

/// The menu-bar lotus icon for a capture state (spec Task 2). Idle = the plain
/// two-tone mark. Listening/processing add a soft magenta glow on the petals
/// and a glowing pink activity dot to the right; in processing the caller
/// pulses `dotOpacity`.
private struct StatusIcon: View {
    let state: DictationController.CaptureState
    let dotOpacity: Double

    private var active: Bool { state != .idle }

    var body: some View {
        HStack(spacing: 3) {
            LotusMark(size: 15)
                .frame(width: 16, height: 15)
                // Soft magenta glow on the petals while active (spec Task 2:
                // #FF5CA8 ~55%, ~8pt blur — trimmed a touch so it isn't clipped
                // at menu-bar scale).
                .shadow(
                    color: active ? Color.lotusAccentPink.opacity(0.55) : .clear,
                    radius: active ? 5 : 0)
            if active {
                Circle()
                    .fill(Color.lotusAccentPink)
                    .frame(width: 5, height: 5)
                    .opacity(dotOpacity)
                    .shadow(color: Color.lotusAccentPink.opacity(0.7), radius: 2)
            }
        }
        .padding(3)  // breathing room so the glow isn't clipped by the bounds
    }
}
