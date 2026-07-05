import Testing
@testable import LotusScribe

/// Pure view-model tests (spec §2B): the levels window trims to barCount,
/// preserves order, and drops oldest first.
@MainActor
struct PillViewModelTests {
    @Test func pushAppendsInOrder() {
        let model = PillViewModel()
        model.push(level: 0.1)
        model.push(level: 0.2)
        model.push(level: 0.3)
        #expect(model.levels == [0.1, 0.2, 0.3])
    }

    @Test func pushTrimsToBarCountDroppingOldestFirst() {
        let model = PillViewModel()
        let overflow = 5
        for i in 0..<(PillMetrics.barCount + overflow) {
            model.push(level: Float(i))
        }
        #expect(model.levels.count == PillMetrics.barCount)
        #expect(model.levels.first == Float(overflow))
        #expect(model.levels.last == Float(PillMetrics.barCount + overflow - 1))
    }
}
