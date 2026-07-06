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
    /// D64: secure-input blocked — pre-dictation environment state, not a
    /// pipeline stage, hence top-level rather than the staged family.
    case blocked
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
        case .blocked:
            return PillMetrics.blockedFlashDuration
        case .hidden, .warming, .recording, .processing,
             .stagedSuccess(.pending):
            return nil
        }
    }
}

/// D31: the single definition site for every pill size/position literal —
/// no second site anywhere (R21 lesson).
enum PillMetrics {
    // Wider capsule (spec §5 HUD: mic dot + 12 bars + LISTENING + hotkey chip).
    static let contentSize = CGSize(width: 300, height: 52)
    static let bottomMargin: CGFloat = 24
    // Spec §5: 12-bar gradient waveform.
    static let barCount = 12
    // Spec §5: Inserted auto-dismisses ~900ms.
    static let flashDuration: TimeInterval = 0.9
    /// D48: staged terminals need more read time (two symbols + amber).
    static let stagedFlashDuration: TimeInterval = 1.2
    /// D64: a sentence ("Can't dictate here") needs more read time than
    /// symbols.
    static let blockedFlashDuration: TimeInterval = 1.6
}
