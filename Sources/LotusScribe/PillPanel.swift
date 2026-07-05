import AppKit

/// Borderless floating container for the pill (spec §2B). Display-only:
/// never activates, never takes key/main, ignores the mouse — the focused
/// app keeps every keystroke while the pill is visible.
final class PillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: PillMetrics.contentSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        // PillController owns this panel for the app's lifetime; the AppKit
        // default (release on close) would over-release under ARC.
        isReleasedWhenClosed = false
        // R23: macOS 26 fitting-size autosizing is broken for SwiftUI-hosted
        // windows — size explicitly from D31. Must match PillView's root frame.
        setContentSize(PillMetrics.contentSize)
    }

    // Display-only invariant (spec §2B): the pill can never steal focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Bottom-center of `screen`: horizontally centered, bottom edge at
    /// `visibleFrame.minY + bottomMargin` (D31). No-op when screen is nil
    /// (headless edge case — the pill just keeps its last origin).
    func positionBottomCenter(on screen: NSScreen?) {
        guard let screen else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.minY + PillMetrics.bottomMargin))
    }
}
