// NSApplication bootstrap — no storyboard, no SwiftUI @main (phase-0-spec repo layout).
import AppKit
import Foundation

// Build tool (icons Task 3): `--render-app-icon <dir>` writes the AppIcon asset
// set and exits BEFORE any normal launch — no permission prompts, no status
// item. Run via `make appicon`.
if MainActor.assumeIsolated({ AppIconRenderer.handleCommandLineIfNeeded() }) {
    exit(0)
}

// Input Monitoring is requested here — before ANYTHING calls
// AXIsProcessTrusted() — but ONLY when Microphone is already granted: a
// returning, onboarded user (mic is the first real TCC prompt, D68). For that
// user we want the hotkey live immediately, so the IM request fires up front
// where the rdar ordering below still holds.
//
// A fresh / mid-onboarding user (mic not yet granted) gets NO launch prompt:
// the IM request fires only when they click "Allow…" in onboarding. That is
// the point — no unsolicited Input Monitoring prompt before the user has
// engaged at all.
//
// rdar://7381305: IOHIDRequestAccess(ListenEvent) silently no-ops — no
// prompt, no pane registration — if AXIsProcessTrusted() ran earlier in the
// process. logStatusAtLaunch() and the onboarding 1 s poll both call it, so
// the request must precede AppKit. (isMicrophoneGranted() reads
// AVCaptureDevice status, not AX, so the gate does not disturb this ordering.)
// Guarded out of hosted-test launches so `make test` never blocks on a dialog.
if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
    if Permissions.isMicrophoneGranted() {
        _ = Permissions.requestListenEventAccess()
    }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
