import Foundation

// Pure pill UI model — no AppKit, headless-tested (D14).
// See docs/phase-2-spec.md §"Sub-phase 2B".

/// Cleanup slot of the two-stage success display (spec §3D, D46). A display
/// instruction only — the pill holds no pipeline knowledge.
enum CleanupStage: Equatable {
    case pending, done, missed
}

/// Display states for the dictation pill. Owned by PillViewModel; driven
/// by DictationController in 2C.
enum PillState: Equatable {
    case hidden, warming, recording, processing, success, error
    case stagedSuccess(cleanup: CleanupStage)
}

extension PillState {
    /// nil = sticky (stays until the next update); non-nil = auto-hide
    /// after this interval. Pure state property so the flash/sticky
    /// decision is headless-testable (D46).
    var flashDuration: TimeInterval? {
        switch self {
        case .success, .error:
            return PillMetrics.flashDuration
        case .stagedSuccess(.done), .stagedSuccess(.missed):
            return PillMetrics.stagedFlashDuration
        case .hidden, .warming, .recording, .processing,
             .stagedSuccess(.pending):
            return nil
        }
    }
}

/// D31: the single definition site for every pill size/position literal —
/// no second site anywhere (R21 lesson).
enum PillMetrics {
    static let contentSize = CGSize(width: 260, height: 52)
    static let bottomMargin: CGFloat = 24
    static let barCount = 24
    static let flashDuration: TimeInterval = 0.8
    /// D48: staged terminals need more read time (two symbols + amber).
    static let stagedFlashDuration: TimeInterval = 1.2
}
