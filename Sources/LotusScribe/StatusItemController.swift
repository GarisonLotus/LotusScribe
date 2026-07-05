import AppKit

/// Owns the NSStatusItem: fixed SF Symbol icon and a menu with Settings… and Quit.
/// NSObject subclass so it can be an NSMenuItem action target.
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private var settingsWindowController: SettingsWindowController?

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
        menu.addItem(NSMenuItem(
            title: "Quit LotusScribe",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    // Lazy: the window is only built on first open; kept so reopening focuses it.
    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }
}
