import Foundation
import Testing
@testable import TypeCue

/// Exercises the coordinator through its injectable seam (a temp store + isolated
/// settings, no first-launch seeding). Only touches wiring that doesn't require the
/// Accessibility permission or open windows, so it stays stable in the headless host.
@MainActor
@Suite("AppCoordinator wiring")
struct AppCoordinatorTests {
    private func makeCoordinator() -> AppCoordinator {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ScriptStore(directory: dir)
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "coord-\(UUID().uuidString)")!)
        return AppCoordinator(store: store, settings: settings, seedSample: false)
    }

    @Test("Menu bar symbol and VoiceOver label reflect session state")
    func menuBarReflectsState() {
        let coordinator = makeCoordinator()
        #expect(coordinator.menuBarSymbol == "keyboard")
        #expect(coordinator.menuBarAccessibilityLabel == "TypeCue, idle")

        let script = Script(name: "Demo", blocks: [TextBlock(text: "a"), TextBlock(text: "b")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)
        #expect(coordinator.menuBarSymbol == "arrowtriangle.right.circle")
        #expect(coordinator.menuBarAccessibilityLabel == "TypeCue, ready to type block 1 of 2")
    }

    @Test("resetSequence re-arms after the script completes")
    func resetReArms() {
        let coordinator = makeCoordinator()
        let script = Script(name: "Demo", blocks: [TextBlock(text: "only")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)

        _ = coordinator.session.advance()
        #expect(coordinator.session.state == .complete(total: 1))

        coordinator.resetSequence()
        #expect(coordinator.session.state == .armed(nextIndex: 0, total: 1))
    }
}
