import KeyboardShortcuts
import SwiftUI

/// Steps of the first-run flow. Backed by an `Int` so `Fix Permissions…` can jump
/// straight to the permission step and the page dots can index cleanly.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permission
    case ready
}

/// First-run flow that explains what TypeCue is for, walks the user through the single
/// Accessibility permission (with a live Test Pad, because `AXIsProcessTrusted()` can
/// report `true` before the permission is actually functional), and points at the bundled
/// "TypeCue tour" sample. Re-openable any time from the menu.
struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var testInput = ""
    @FocusState private var testFieldFocused: Bool

    private let expected = "TypeCue works!"

    // Fixed layout dimensions that must grow with Dynamic Type so labels stay aligned.
    @ScaledMetric private var workflowNumberWidth: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                stepContent
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 500)
        .onAppear { coordinator.permissions.refresh() }
        // Permission status refreshes when the app is reactivated (see AppDelegate's
        // applicationDidBecomeActive) - i.e. exactly when the user returns from granting
        // access in System Settings. No idle polling timer needed.
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch coordinator.onboardingStep {
        case .welcome: welcomeStep
        case .permission: permissionStep
        case .ready: readyStep
        }
    }

    // MARK: Step 1 - What is TypeCue

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome to TypeCue")
                .font(.largeTitle).bold()
            Text("TypeCue types your script into the focused field, one press per block, so recordings and live demos never show a typo. Great for demo videos, tutorials, webinars, and live presentations - anywhere an audience is watching you type.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("How it works")
                    .font(.headline)
                workflowRow(1, "Write a script - blocks of text in the order you'll play them.")
                workflowRow(2, "Focus the field you want to type into.")
                workflowRow(3, "Press your hotkey each time you want the next block typed, human-paced.")
            }
        }
    }

    // MARK: Step 2 - Permission + Test Pad

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grant one permission")
                .font(.largeTitle).bold()
            Text("TypeCue needs Accessibility access to send keystrokes to other apps - that's the only permission it uses.")
                .foregroundStyle(.secondary)

            permissionRow
            Divider()
            testPad
        }
    }

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: coordinator.permissions.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(coordinator.permissions.isTrusted ? .green : .orange)
                Text("Accessibility")
                    .font(.headline)
                Spacer()
                Text(coordinator.permissions.isTrusted ? "Granted" : "Not granted")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("permissionStatus")
            }
            Text("Grant it in System Settings > Privacy & Security > Accessibility, then return here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !coordinator.permissions.isTrusted {
                HStack {
                    Button("Grant Accessibility…") {
                        coordinator.permissions.requestAccessibilityPrompt()
                        coordinator.permissions.openAccessibilitySettings()
                    }
                    Button("Refresh Status") { coordinator.permissions.refresh() }
                }
            }
        }
    }

    private var testPad: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test it")
                .font(.headline)
            Text("Accessibility can say Granted before it actually works. Click the box, press Test Type, and check that \u{201C}\(expected)\u{201D} appears.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Typed text appears here", text: $testInput)
                .textFieldStyle(.roundedBorder)
                .focused($testFieldFocused)
                .accessibilityIdentifier("testPadField")

            HStack {
                Button("Test Type") {
                    testInput = ""
                    testFieldFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        coordinator.typeTestString(expected)
                    }
                }
                .disabled(!coordinator.permissions.isTrusted)
                .accessibilityIdentifier("testTypeButton")

                if testInput == expected {
                    Label("Verified", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("testVerified")
                }
            }
        }
    }

    // MARK: Step 3 - You're set

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You're all set")
                .font(.largeTitle).bold()
            Text("Try the sample script to see it in action, or jump straight into your own.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                readinessRow(
                    done: coordinator.permissions.isTrusted,
                    title: "Accessibility",
                    detail: coordinator.permissions.isTrusted
                        ? "Granted - TypeCue can type for you."
                        : "Not granted yet - typing won't work until you enable it in Settings."
                )
                readinessRow(
                    done: hotkeyDescription != nil,
                    title: "Hotkey",
                    detail: hotkeyDescription.map { "Press \($0) anywhere to type the next block." }
                        ?? "Not set yet - add one in Settings."
                )
                readinessRow(
                    done: true,
                    title: "Sample script",
                    detail: "\u{201C}TypeCue tour\u{201D} is ready in your list."
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button {
                        coordinator.startTour()
                    } label: {
                        Label("Try the Sample Script", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        coordinator.openEditor()
                    } label: {
                        Label("Edit Scripts", systemImage: "square.and.pencil")
                    }
                    Button {
                        coordinator.toggleFloatingPanel()
                    } label: {
                        Label("Show Panel", systemImage: "macwindow")
                    }
                }
                Text("Loads \u{201C}TypeCue tour\u{201D} as your active script - focus any text field and press your hotkey to watch it type.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Pace your blocks with inline markers like [0.5], [speed:20], and [enter] - the full list is under Formatting in the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hotkeyDescription: String? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .typeNextBlock) else { return nil }
        let description = shortcut.description.trimmingCharacters(in: .whitespaces)
        return description.isEmpty ? nil : description
    }

    private func readinessRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(done ? "ready" : "not ready"), \(detail)")
    }

    // MARK: - Footer navigation

    private var footer: some View {
        HStack {
            Button("Back") { goto(step.previous) }
                .disabled(step == .welcome)

            Spacer()

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.self) { s in
                    Circle()
                        .fill(s == step ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")

            Spacer()

            if step == .ready {
                Button("Done") { coordinator.closeOnboarding() }
                    .keyboardShortcut(.defaultAction)
            } else if step == .permission && !permissionReady {
                // Soft gate: proceeding is allowed, but the label is honest that the
                // permission isn't verified working yet.
                Button("Skip for now") { goto(step.next) }
            } else {
                Button("Continue") { goto(step.next) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }

    // MARK: - Helpers

    private var step: OnboardingStep { coordinator.onboardingStep }

    /// Whether the permission step is verified ready (trusted + functional test passed).
    private var permissionReady: Bool {
        OnboardingGate.canProceed(
            isTrusted: coordinator.permissions.isTrusted,
            testPassed: testInput == expected
        )
    }

    private func goto(_ newStep: OnboardingStep) {
        if reduceMotion {
            coordinator.onboardingStep = newStep
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                coordinator.onboardingStep = newStep
            }
        }
    }

    private func workflowRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.accentColor)
                .frame(width: workflowNumberWidth, alignment: .trailing)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}

private extension OnboardingStep {
    var next: OnboardingStep { OnboardingStep(rawValue: rawValue + 1) ?? self }
    var previous: OnboardingStep { OnboardingStep(rawValue: rawValue - 1) ?? self }
}
