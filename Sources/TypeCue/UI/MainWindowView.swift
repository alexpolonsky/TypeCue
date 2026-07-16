import SwiftUI

/// The two sections of the app's single primary window.
enum EditorTab: Hashable {
    case scripts
    case settings
}

/// The app's one primary window. A segmented control switches between the Scripts editor
/// and Settings, so the menu bar's "Edit Scripts…" and "Settings…" both land here rather
/// than opening two separate windows. Onboarding stays a separate window.
struct MainWindowView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        return VStack(spacing: 0) {
            Picker("Section", selection: $coordinator.editorTab) {
                Text("Scripts").tag(EditorTab.scripts)
                Text("Settings").tag(EditorTab.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Divider()

            switch coordinator.editorTab {
            case .scripts:
                ScriptsEditorView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 480)
        .alert(
            "Import / Export Failed",
            isPresented: Binding(
                get: { coordinator.importExportError != nil },
                set: { if !$0 { coordinator.importExportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.importExportError = nil }
        } message: {
            if let message = coordinator.importExportError {
                Text(message)
            }
        }
    }
}
