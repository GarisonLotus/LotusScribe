import Testing
@testable import LotusScribe

/// Headless truth table for `OnboardingStep.resolve` (spec §7B, D67/D68):
/// first ungranted in order mic → accessibility → inputMonitoring, else
/// `.done`. All 8 snapshot combinations — Input Monitoring is
/// UNCONDITIONAL (D68), so no combination ever skips its row.
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

    // Mic granted → accessibility is next, ahead of input monitoring.

    @Test func micOnlyResolvesToAccessibility() {
        #expect(resolve(mic: true, ax: false, listen: false) == .accessibility)
    }

    @Test func micAndListenResolvesToAccessibility() {
        #expect(resolve(mic: true, ax: false, listen: true) == .accessibility)
    }

    // D68: input monitoring is a real, unconditional step.

    @Test func micAndAccessibilityResolvesToInputMonitoring() {
        #expect(resolve(mic: true, ax: true, listen: false) == .inputMonitoring)
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
