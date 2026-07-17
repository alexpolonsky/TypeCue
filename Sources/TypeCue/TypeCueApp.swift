import SwiftUI

@main
struct TypeCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environment(coordinator)
        } label: {
            menuBarImage
                .accessibilityLabel(coordinator.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.menu)
    }

    /// The brand mark (template asset; caret present while armed) for steady states,
    /// SF Symbols with a pulse for the transient ones (typing, warning flash).
    @ViewBuilder
    private var menuBarImage: some View {
        switch coordinator.menuBarGlyph {
        case .asset(let name):
            Image(name)
        case .symbol(let name):
            Image(systemName: name)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: coordinator.isTyping || coordinator.isFlashingWarning)
        }
    }
}
