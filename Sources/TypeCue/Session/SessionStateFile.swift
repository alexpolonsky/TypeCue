import Foundation

/// Writes a small machine-readable snapshot of the session to `state.json` (next to
/// `scripts.json`) whenever it changes, so external tools - AI agents and assistants,
/// shell scripts - can observe the app after firing a `typecue://` command.
///
/// Deliberately excludes block text: scripts may hold sensitive demo content, and any
/// local process can read this file.
struct SessionStateFile {
    struct Snapshot: Codable, Equatable {
        var schemaVersion = 1
        /// "idle" | "armed" | "complete"
        var status: String
        var activeScriptID: String?
        var activeScriptName: String?
        /// 0-based index of the next block to type; present only while armed.
        var nextBlockIndex: Int?
        var totalBlocks: Int?
        var isTyping: Bool
        var updatedAt: String
    }

    let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("state.json")
    }

    func write(state: SessionState, activeScript: Script?, isTyping: Bool, now: Date = Date()) {
        var snapshot = Snapshot(
            status: "idle",
            activeScriptID: activeScript?.id.uuidString,
            activeScriptName: activeScript?.name,
            nextBlockIndex: nil,
            totalBlocks: nil,
            isTyping: isTyping,
            updatedAt: ISO8601DateFormatter().string(from: now)
        )
        switch state {
        case .idle:
            break
        case .armed(let nextIndex, let total):
            snapshot.status = "armed"
            snapshot.nextBlockIndex = nextIndex
            snapshot.totalBlocks = total
        case .complete(let total):
            snapshot.status = "complete"
            snapshot.totalBlocks = total
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
