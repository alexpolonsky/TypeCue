import SwiftUI

@main
struct TypeCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environment(coordinator)
        } label: {
            Image(systemName: coordinator.menuBarSymbol)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, isActive: coordinator.isTyping || coordinator.isFlashingWarning)
                .accessibilityLabel(coordinator.menuBarAccessibilityLabel)
        }
        .menuBarExtraStyle(.menu)
    }
}
