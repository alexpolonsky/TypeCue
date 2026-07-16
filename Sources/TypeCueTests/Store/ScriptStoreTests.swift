import Foundation
import Testing
@testable import TypeCue

@MainActor
@Suite("ScriptStore")
struct ScriptStoreTests {
    private func makeTempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func removeDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("add / update / delete round-trip")
    func addUpdateDelete() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }
        let store = ScriptStore(directory: dir)
        #expect(store.scripts.isEmpty)

        var script = Script(name: "Demo", blocks: [TextBlock(text: "hello")])
        store.addScript(script)
        #expect(store.scripts.count == 1)
        #expect(store.scripts.first == script)

        script.name = "Renamed"
        script.blocks.append(TextBlock(text: "world"))
        store.updateScript(script)
        #expect(store.scripts.count == 1)
        #expect(store.scripts.first?.name == "Renamed")
        #expect(store.scripts.first?.blocks.count == 2)

        store.deleteScript(id: script.id)
        #expect(store.scripts.isEmpty)
    }

    @Test("Persistence round-trips across two store instances")
    func persistenceRoundTrip() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }

        let script = Script(
            name: "Persisted",
            blocks: [
                TextBlock(text: "[1][speed:50]one[speed:default]"),
                TextBlock(text: "two")
            ]
        )
        let writer = ScriptStore(directory: dir)
        writer.addScript(script)
        writer.flush()

        let reader = ScriptStore(directory: dir)
        #expect(reader.scripts == writer.scripts)
        #expect(reader.scripts.first == script)
    }

    @Test("flush persists a debounced save immediately")
    func flushPersistsImmediately() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }

        let store = ScriptStore(directory: dir)
        store.addScript(Script(name: "Debounced", blocks: [TextBlock(text: "x")]))
        // The debounce timer hasn't fired yet; flush forces the write now.
        store.flush()

        let reader = ScriptStore(directory: dir)
        #expect(reader.scripts.count == 1)
        #expect(reader.scripts.first?.name == "Debounced")
    }

    @Test("Missing file starts empty without crashing")
    func missingFileStartsEmpty() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }
        let store = ScriptStore(directory: dir)
        #expect(store.scripts.isEmpty)
    }

    @Test("Corrupt file starts empty without crashing")
    func corruptFileStartsEmpty() throws {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("scripts.json")
        try Data("{ not valid json".utf8).write(to: fileURL)

        let store = ScriptStore(directory: dir)
        #expect(store.scripts.isEmpty)

        // A subsequent mutation should overwrite the corrupt file cleanly.
        let script = Script(name: "Recovered")
        store.addScript(script)
        store.flush()
        let reader = ScriptStore(directory: dir)
        #expect(reader.scripts == [script])
    }

    @Test("Block reorder persists")
    func blockReorderPersists() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }

        let b0 = TextBlock(text: "zero")
        let b1 = TextBlock(text: "one")
        let b2 = TextBlock(text: "two")
        let script = Script(name: "Reorder", blocks: [b0, b1, b2])

        let store = ScriptStore(directory: dir)
        store.addScript(script)
        store.moveBlock(inScriptID: script.id, from: 0, to: 2)

        let expectedOrder = [b1, b2, b0]
        #expect(store.scripts.first?.blocks == expectedOrder)
        store.flush()

        let reader = ScriptStore(directory: dir)
        #expect(reader.scripts.first?.blocks == expectedOrder)
    }

    @Test("moveBlock ignores out-of-range indices")
    func moveBlockOutOfRange() {
        let dir = makeTempDirectory()
        defer { removeDirectory(dir) }
        let script = Script(name: "Guard", blocks: [TextBlock(text: "a"), TextBlock(text: "b")])
        let store = ScriptStore(directory: dir)
        store.addScript(script)

        store.moveBlock(inScriptID: script.id, from: 5, to: 0)
        store.moveBlock(inScriptID: script.id, from: 0, to: 9)
        #expect(store.scripts.first?.blocks.map(\.text) == ["a", "b"])
    }
}
