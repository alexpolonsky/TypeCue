import Testing
@testable import TypeCue

@Suite("OnboardingGate")
struct OnboardingGateTests {
    @Test("Either signal - trust or a passed typing test - is enough to continue")
    func canProceedTruthTable() {
        #expect(OnboardingGate.canProceed(isTrusted: true, testPassed: true) == true)
        #expect(OnboardingGate.canProceed(isTrusted: true, testPassed: false) == true)
        #expect(OnboardingGate.canProceed(isTrusted: false, testPassed: true) == true)
        #expect(OnboardingGate.canProceed(isTrusted: false, testPassed: false) == false)
    }
}
