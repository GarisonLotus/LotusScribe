import Testing
@testable import LotusScribe

/// Pure flash/sticky mapping tests (spec §3D, D46): `flashDuration` is the
/// headless seam — nil means the state sticks until the next update;
/// non-nil is the auto-hide interval PillController schedules.
struct PillStateTests {
    @Test func successFlashesAtLegacyFlashDuration() {
        #expect(PillState.success.flashDuration == PillMetrics.flashDuration)
    }

    @Test func errorFlashesAtLegacyFlashDuration() {
        #expect(PillState.error.flashDuration == PillMetrics.flashDuration)
    }

    @Test func stagedDoneFlashesAtStagedFlashDuration() {
        #expect(
            PillState.stagedSuccess(cleanup: .done).flashDuration
                == PillMetrics.stagedFlashDuration)
    }

    @Test func stagedMissedFlashesAtStagedFlashDuration() {
        #expect(
            PillState.stagedSuccess(cleanup: .missed).flashDuration
                == PillMetrics.stagedFlashDuration)
    }

    /// `.pending` has no timer of its own (D47) — the cleanup service's
    /// timeout bounds it; it must never schedule a flash-hide.
    @Test func pendingAndNonTerminalStatesAreSticky() {
        let sticky: [PillState] = [
            .hidden, .warming, .recording, .processing,
            .stagedSuccess(cleanup: .pending),
        ]
        for state in sticky {
            #expect(state.flashDuration == nil)
        }
    }

    @Test func stagedEqualityFollowsCleanupStage() {
        #expect(
            PillState.stagedSuccess(cleanup: .done)
                == PillState.stagedSuccess(cleanup: .done))
        #expect(
            PillState.stagedSuccess(cleanup: .done)
                != PillState.stagedSuccess(cleanup: .missed))
        #expect(PillState.stagedSuccess(cleanup: .done) != PillState.success)
    }
}
