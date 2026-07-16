import Foundation

/// Pure, testable readiness logic for the onboarding permission step.
///
/// "Ready" (a *soft* gate - the user can still skip) means the process is a trusted
/// Accessibility client AND the functional Test Pad check has confirmed keystrokes
/// actually reach a field. Both are required because `AXIsProcessTrusted()` can report
/// `true` before the grant is fully live (documented macOS quirk), so trust alone isn't
/// proof that typing works.
enum OnboardingGate {
    static func canProceed(isTrusted: Bool, testPassed: Bool) -> Bool {
        isTrusted && testPassed
    }
}
