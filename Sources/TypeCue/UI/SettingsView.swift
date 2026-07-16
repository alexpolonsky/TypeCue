import KeyboardShortcuts
import SwiftUI

/// Modeless settings: changes apply immediately (macOS convention, no Save/Cancel).
struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Form {
            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Type next block", name: .typeNextBlock)
                Text("Press this anywhere to type the next block. Press it again while typing to stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Speed") {
                LabeledContent("Typing speed") {
                    Text(speedLabel)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: baseDelay, in: 0.005...0.3, step: 0.005) {
                    Text("Typing speed")
                } minimumValueLabel: {
                    Image(systemName: "hare")
                } maximumValueLabel: {
                    Image(systemName: "tortoise")
                }
                .labelsHidden()

                Toggle("Natural rhythm", isOn: jitterEnabled)
                Text("Varies the pace and pauses at spaces and punctuation, so it reads like a real person.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Line breaks") {
                Picker("When a block has multiple lines", selection: newlineMode) {
                    Text("Insert a line break (Shift+Return)").tag(NewlineMode.shiftReturn)
                    Text("Press Return").tag(NewlineMode.plainReturn)
                }
                .pickerStyle(.radioGroup)
                Text("Chat apps send the message on Return. Inserting a line break keeps multi-line blocks from sending themselves; use [enter] to send on purpose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        // Tall enough to show all three sections without scrolling at the minimum
        // window size (the grouped form's content is ~510pt with default text size,
        // measured from a window capture).
        .frame(minWidth: 440, minHeight: 520)
    }

    private var speedLabel: String {
        "\(Int(coordinator.settings.baseDelay * 1000)) ms / character"
    }

    // The settings store is a `let` on the coordinator, so bind through the reference
    // explicitly rather than via a projected key-path binding (which requires a var).
    private var baseDelay: Binding<TimeInterval> {
        Binding(get: { coordinator.settings.baseDelay }, set: { coordinator.settings.baseDelay = $0 })
    }
    private var jitterEnabled: Binding<Bool> {
        Binding(get: { coordinator.settings.jitterEnabled }, set: { coordinator.settings.jitterEnabled = $0 })
    }
    private var newlineMode: Binding<NewlineMode> {
        Binding(get: { coordinator.settings.newlineMode }, set: { coordinator.settings.newlineMode = $0 })
    }
}
