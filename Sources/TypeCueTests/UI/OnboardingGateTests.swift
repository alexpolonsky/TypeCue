import Testing
@testable import TypeCue

@Suite("OnboardingGate")
struct OnboardingGateTests {
    @Test("Ready only when trusted AND the functional test passed")
    func canProceedTruthTable() {
        #expect(OnboardingGate.canProceed(isTrusted: true, testPassed: true) == true)
        #expect(OnboardingGate.canProceed(isTrusted: true, testPassed: false) == false)
        #expect(OnboardingGate.canProceed(isTrusted: false, testPassed: true) == false)
        #expect(OnboardingGate.canProceed(isTrusted: false, testPassed: false) == false)
    }
}
