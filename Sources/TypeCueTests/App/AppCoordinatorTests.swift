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
        let suite = "coord-\(UUID().uuidString)"
        let settings = SettingsStore(defaults: UserDefaults(suiteName: suite)!)
        // Isolated defaults so tests never write the user's real active-script id.
        return AppCoordinator(store: store, settings: settings, seedSample: false, defaults: UserDefaults(suiteName: suite)!)
    }

    @Test("Menu bar symbol and VoiceOver label reflect session state")
    func menuBarReflectsState() {
        let coordinator = makeCoordinator()
        #expect(coordinator.menuBarGlyph == .asset("MenuBarIdle"))
        #expect(coordinator.menuBarAccessibilityLabel == "TypeCue, idle")

        let script = Script(name: "Demo", blocks: [TextBlock(text: "a"), TextBlock(text: "b")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)
        #expect(coordinator.menuBarGlyph == .asset("MenuBarArmed"))
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

    // MARK: - typecue:// URL commands

    @Test("activate-script by unique name activates; missing or ambiguous names warn")
    func activateScriptByName() {
        let coordinator = makeCoordinator()
        let demo = Script(name: "Demo", blocks: [TextBlock(text: "a")])
        coordinator.store.addScript(demo)
        coordinator.store.addScript(Script(name: "Twin", blocks: []))
        coordinator.store.addScript(Script(name: "Twin", blocks: []))

        coordinator.handle(url: URL(string: "typecue://activate-script?name=Demo")!)
        #expect(coordinator.session.activeScriptID == demo.id)

        coordinator.handle(url: URL(string: "typecue://activate-script?name=Nope")!)
        #expect(coordinator.session.activeScriptID == demo.id)
        #expect(coordinator.warning?.contains("No script named") == true)

        coordinator.handle(url: URL(string: "typecue://activate-script?name=Twin")!)
        #expect(coordinator.session.activeScriptID == demo.id)
        #expect(coordinator.warning?.contains("2 scripts") == true)
    }

    @Test("activate-script by id activates regardless of duplicate names")
    func activateScriptByID() {
        let coordinator = makeCoordinator()
        let first = Script(name: "Twin", blocks: [TextBlock(text: "a")])
        let second = Script(name: "Twin", blocks: [TextBlock(text: "b")])
        coordinator.store.addScript(first)
        coordinator.store.addScript(second)

        coordinator.handle(url: URL(string: "typecue://activate-script?id=\(second.id.uuidString)")!)
        #expect(coordinator.session.activeScriptID == second.id)
    }

    @Test("reset-session URL re-arms; unknown command warns")
    func urlResetAndUnknown() {
        let coordinator = makeCoordinator()
        let script = Script(name: "Demo", blocks: [TextBlock(text: "only")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)
        _ = coordinator.session.advance()

        coordinator.handle(url: URL(string: "typecue://reset-session")!)
        #expect(coordinator.session.state == .armed(nextIndex: 0, total: 1))

        coordinator.handle(url: URL(string: "typecue://frobnicate")!)
        #expect(coordinator.warning?.contains("Unknown TypeCue command") == true)
    }

    @Test("reload URL picks up externally edited scripts.json without moving the cursor")
    func urlReload() throws {
        let coordinator = makeCoordinator()
        let script = Script(name: "Demo", blocks: [TextBlock(text: "a"), TextBlock(text: "b")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)
        coordinator.store.flush()
        _ = coordinator.session.advance()

        // External edit: append a block to the active script on disk.
        var edited = script
        edited.blocks.append(TextBlock(text: "c"))
        let data = try JSONEncoder().encode([edited])
        try data.write(to: coordinator.store.fileURL)

        coordinator.handle(url: URL(string: "typecue://reload")!)
        #expect(coordinator.store.scripts.first?.blocks.count == 3)
        #expect(coordinator.session.state == .armed(nextIndex: 1, total: 3))
    }

    @Test("state.json snapshot tracks activation and reset")
    func stateFilePublishes() throws {
        let coordinator = makeCoordinator()
        let script = Script(name: "Demo", blocks: [TextBlock(text: "a"), TextBlock(text: "b")])
        coordinator.store.addScript(script)
        coordinator.setActiveScript(script.id)

        let stateURL = coordinator.store.fileURL.deletingLastPathComponent().appendingPathComponent("state.json")
        let data = try Data(contentsOf: stateURL)
        let snapshot = try JSONDecoder().decode(SessionStateFile.Snapshot.self, from: data)
        #expect(snapshot.status == "armed")
        #expect(snapshot.activeScriptName == "Demo")
        #expect(snapshot.nextBlockIndex == 0)
        #expect(snapshot.totalBlocks == 2)
        #expect(snapshot.isTyping == false)
    }
}
