import AppKit
import Testing
@testable import LotusScribe

/// Smoke test (R3): the hosted app has already run
/// applicationDidFinishLaunching by the time tests execute — assert the
/// delegate really composed the dictation pipeline, not just that it links.
@Test @MainActor func appDelegateInitializes() {
    let delegate = NSApp.delegate as? AppDelegate
    #expect(delegate?.dictationController != nil)
}

/// The programmatic Edit menu must route Cmd-V to paste: (LSUIElement fix).
@Test @MainActor func mainMenuRoutesPaste() {
    MainMenu.install()
    let paste = (NSApp.mainMenu?.items ?? [])
        .compactMap(\.submenu).flatMap(\.items)
        .first { $0.action == #selector(NSText.paste(_:)) }
    #expect(paste?.keyEquivalent == "v")
    #expect(paste?.target == nil)  // nil target → responder chain dispatch
}
