import KeyboardShortcuts
import SwiftUI

/// Contents of the menu bar dropdown. Menu style (not a popover) for instant, native
/// system-menu behavior. Kept deliberately short: status, the two things you do while
/// recording, script switching, and a way into the editor/settings. Script management
/// (new/sample/import/export) lives in the editor window.
struct MenuContent: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Group {
            statusSection
            Divider()

            Button(typeNextTitle) { coordinator.typeNextBlock() }
                .disabled(!canTypeNext)
            Button("Reset Script") { coordinator.resetSequence() }
                .disabled(coordinator.session.activeScriptID == nil)

            activeScriptMenu
            Button(coordinator.floatingPanel.isVisible ? "Hide Panel" : "Show Panel") {
                coordinator.toggleFloatingPanel()
            }
            Divider()

            Button("Edit Scripts") { coordinator.openEditor() }
            Button("Settings") { coordinator.openSettings() }
            Button("How TypeCue Works") { coordinator.openOnboarding() }
            if !coordinator.permissions.isTrusted {
                Button("Fix Permissions…") { coordinator.openOnboarding(step: .permission) }
            }
            Divider()

            Button("Quit TypeCue") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    // MARK: - Status (at most two lines)

    @ViewBuilder
    private var statusSection: some View {
        if let warning = coordinator.warning {
            Label(warning, systemImage: "exclamationmark.triangle.fill")
        }
        if let script = coordinator.activeScript {
            Text(headlineText(for: script))
            if let preview = nextPreview(for: script) {
                Text("Next: \(preview)")
            } else if isComplete {
                Text("Script complete - choose Reset Script to start over.")
            }
        } else {
            Text("No active script - pick one below")
        }
    }

    private var isComplete: Bool {
        if case .complete(let total) = coordinator.session.state { return total > 0 }
        return false
    }

    @ViewBuilder
    private var activeScriptMenu: some View {
        Menu("Active Script") {
            Button("None") { coordinator.setActiveScript(nil) }
            Divider()
            ForEach(coordinator.store.scripts) { script in
                Button {
                    coordinator.setActiveScript(script.id)
                } label: {
                    if script.id == coordinator.session.activeScriptID {
                        Label(script.name, systemImage: "checkmark")
                    } else {
                        Text(script.name)
                    }
                }
            }
        }
        .disabled(coordinator.store.scripts.isEmpty)
    }

    // MARK: - Derived text

    private var typeNextTitle: String {
        if let hint = shortcutHint { return "Type Next Block  \(hint)" }
        return "Type Next Block"
    }

    private var shortcutHint: String? {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .typeNextBlock) else { return nil }
        let description = shortcut.description.trimmingCharacters(in: .whitespaces)
        return description.isEmpty ? nil : description
    }

    private var canTypeNext: Bool {
        switch coordinator.session.state {
        case .armed: return true
        case .idle, .complete: return false
        }
    }

    /// One line combining script name and position, e.g. "Demo - 2 of 3".
    private func headlineText(for script: Script) -> String {
        let name = script.name.isEmpty ? "Untitled" : script.name
        switch coordinator.session.state {
        case .idle:
            return name
        case .armed(let nextIndex, let total):
            return "\(name) - \(nextIndex + 1) of \(total)"
        case .complete(let total):
            return total == 0 ? "\(name) - empty" : "\(name) - done"
        }
    }

    private func nextPreview(for script: Script) -> String? {
        guard case .armed(let nextIndex, _) = coordinator.session.state,
              script.blocks.indices.contains(nextIndex) else { return nil }
        let text = script.blocks[nextIndex].text
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? text
        let trimmed = firstLine.count > 40 ? String(firstLine.prefix(40)) + "\u{2026}" : firstLine
        return trimmed.isEmpty ? "(empty block)" : trimmed
    }
}
