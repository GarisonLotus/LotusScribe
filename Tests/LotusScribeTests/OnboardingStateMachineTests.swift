import Testing
@testable import LotusScribe

/// Headless truth table for `OnboardingStep.resolve` (spec §7B, D67/D68):
/// first ungranted in order mic → inputMonitoring → accessibility, else
/// `.done`. All 8 snapshot combinations — Input Monitoring is
/// UNCONDITIONAL (D68), so no combination ever skips its row. IM precedes
/// Accessibility by design (rdar://7381305 — see OnboardingStep).
struct OnboardingStateMachineTests {
    private func resolve(mic: Bool, ax: Bool, listen: Bool) -> OnboardingStep {
        OnboardingStep.resolve(PermissionSnapshot(
            micGranted: mic, accessibilityTrusted: ax, listenEventGranted: listen))
    }

    // Mic ungranted always wins, whatever the later grants say.

    @Test func nothingGrantedResolvesToMic() {
        #expect(resolve(mic: false, ax: false, listen: false) == .mic)
    }

    @Test func micUngrantedWithListenGrantedResolvesToMic() {
        #expect(resolve(mic: false, ax: false, listen: true) == .mic)
    }

    @Test func micUngrantedWithAccessibilityGrantedResolvesToMic() {
        #expect(resolve(mic: false, ax: true, listen: false) == .mic)
    }

    @Test func micUngrantedWithBothLaterGrantsResolvesToMic() {
        #expect(resolve(mic: false, ax: true, listen: true) == .mic)
    }

    // Mic granted → input monitoring is next, ahead of accessibility
    // (rdar://7381305 ordering).

    @Test func micOnlyResolvesToInputMonitoring() {
        #expect(resolve(mic: true, ax: false, listen: false) == .inputMonitoring)
    }

    @Test func micAndAccessibilityWithoutListenResolvesToInputMonitoring() {
        #expect(resolve(mic: true, ax: true, listen: false) == .inputMonitoring)
    }

    // Input monitoring granted → accessibility is the last gate.

    @Test func micAndListenResolvesToAccessibility() {
        #expect(resolve(mic: true, ax: false, listen: true) == .accessibility)
    }

    @Test func allGrantedResolvesToDone() {
        #expect(resolve(mic: true, ax: true, listen: true) == .done)
    }

    // Spec §7B: OnboardingStep is Equatable — the view's current-row and
    // Finish-gating checks compare steps directly.

    @Test func stepsCompareByCase() {
        #expect(OnboardingStep.done == OnboardingStep.done)
        #expect(OnboardingStep.mic != OnboardingStep.accessibility)
    }
}
