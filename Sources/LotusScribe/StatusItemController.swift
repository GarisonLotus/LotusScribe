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
        statusItem.button?.image = Self.lotusTemplateImage()

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

    /// Magenta-tint the lotus glyph while dictation is capturing; revert to the
    /// menu-bar template color otherwise (spec §5). Driven by DictationController
    /// through AppDelegate.
    func setListening(_ listening: Bool) {
        statusItem.button?.contentTintColor = listening ? .lotusAccentPink : nil
    }

    /// The three-petal lotus mark as a monochrome template image (spec §1/§5):
    /// a vertical center petal flanked by two petals rotated ±40° about a
    /// shared base. Template = the menu bar tints it (and setListening overrides
    /// to magenta).
    private static func lotusTemplateImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setFill()
        let base = NSPoint(x: size.width / 2, y: 2)
        let petalWidth: CGFloat = 5
        let petalHeight: CGFloat = 13
        for angle in [-40.0, 0.0, 40.0] {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: base.x, yBy: base.y)
            transform.rotate(byDegrees: angle)
            transform.concat()
            let rect = NSRect(x: -petalWidth / 2, y: 0, width: petalWidth, height: petalHeight)
            NSBezierPath(roundedRect: rect, xRadius: petalWidth / 2, yRadius: petalWidth / 2).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
