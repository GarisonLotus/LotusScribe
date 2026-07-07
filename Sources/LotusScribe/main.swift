// NSApplication bootstrap — no storyboard, no SwiftUI @main (phase-0-spec repo layout).
import AppKit
import Foundation

// Input Monitoring MUST be requested here, before ANYTHING calls
// AXIsProcessTrusted(). rdar://7381305: IOHIDRequestAccess(ListenEvent)
// silently no-ops — no prompt, no pane registration — if the accessibility
// status was ever checked earlier in the process. logStatusAtLaunch() and the
// onboarding 1 s poll both call AXIsProcessTrusted(), so any later request is
// dead-on-arrival. Firing first (a) shows the system prompt on true first run
// and (b) registers the app in the Input Monitoring list. Guarded out of
// hosted-test launches so `make test` never blocks on a TCC dialog.
if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil {
    _ = Permissions.requestListenEventAccess()
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
