import Foundation

/// Pure, testable readiness logic for the onboarding permission step.
///
/// The footer shows "Continue" when either signal says typing can work: the process is
/// a trusted Accessibility client, or the functional Test Pad check has already proven
/// keystrokes reach a field (which implies the grant is live even if `AXIsProcessTrusted()`
/// misreports - a documented macOS quirk cuts both ways). Only when neither signal is
/// present does the honest "Skip for now" label appear. The gate stays soft either way.
enum OnboardingGate {
    static func canProceed(isTrusted: Bool, testPassed: Bool) -> Bool {
        isTrusted || testPassed
    }
}
