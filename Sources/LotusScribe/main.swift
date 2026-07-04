// NSApplication bootstrap — no storyboard, no SwiftUI @main (phase-0-spec repo layout).
import AppKit

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
