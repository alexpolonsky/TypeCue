import SwiftUI

/// The tabs of the app's single primary window.
enum EditorTab: Hashable {
    case scripts
    case settings
    case about
}

/// The app's one primary window. Toolbar-style icon tabs switch between the Scripts
/// editor and Settings, so the menu bar's "Edit Scripts…" and "Settings…" both land here
/// rather than opening two separate windows. Onboarding stays a separate window.
struct MainWindowView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                tabItem(.scripts, label: "Scripts", systemImage: "text.badge.checkmark")
                tabItem(.settings, label: "Settings", systemImage: "gearshape")
                tabItem(.about, label: "About", systemImage: "info.circle")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            Divider()

            switch coordinator.editorTab {
            case .scripts:
                ScriptsEditorView()
            case .settings:
                SettingsView()
            case .about:
                AboutView()
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

    /// Toolbar-style tab (icon over label) - the standard chrome for macOS settings
    /// windows.
    private func tabItem(_ tab: EditorTab, label: String, systemImage: String) -> some View {
        let isSelected = coordinator.editorTab == tab
        return Button {
            coordinator.editorTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.caption)
            }
            .frame(width: 62)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .background(
                isSelected ? Color.secondary.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
