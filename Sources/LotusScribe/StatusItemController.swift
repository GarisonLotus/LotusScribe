import AppKit
import os

/// Owns the NSStatusItem: fixed SF Symbol icon and a menu with Settings… and Quit.
/// NSObject subclass so it can be an NSMenuItem action target.
final class StatusItemController: NSObject {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "StatusItemController")
    private let statusItem: NSStatusItem
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(
            systemSymbolName: "mic.fill",
            accessibilityDescription: "LotusScribe"
        )

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
}
