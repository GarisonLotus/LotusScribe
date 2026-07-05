import Foundation

// Pure pill UI model — no AppKit, headless-tested (D14).
// See docs/phase-2-spec.md §"Sub-phase 2B".

/// Display states for the dictation pill. Owned by PillViewModel; driven
/// by DictationController in 2C.
enum PillState: Equatable {
    case hidden, warming, recording, processing, success, error
}

/// D31: the single definition site for every pill size/position literal —
/// no second site anywhere (R21 lesson).
enum PillMetrics {
    static let contentSize = CGSize(width: 260, height: 52)
    static let bottomMargin: CGFloat = 24
    static let barCount = 24
    static let flashDuration: TimeInterval = 0.8
}
