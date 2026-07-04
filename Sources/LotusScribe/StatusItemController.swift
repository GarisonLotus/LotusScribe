import AppKit

/// Owns the NSStatusItem: fixed SF Symbol icon and a menu with a single Quit item.
final class StatusItemController {
    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "mic.fill",
            accessibilityDescription: "LotusScribe"
        )

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit LotusScribe",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }
}
