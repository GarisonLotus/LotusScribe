import AppKit
import Testing
@testable import LotusScribe

/// Smoke test: the hosted test bundle loads and links against the app target.
@Test func appDelegateInitializes() {
    #expect(AppDelegate() is NSApplicationDelegate)
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
