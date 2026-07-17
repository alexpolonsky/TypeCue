import Foundation
import Observation
import os

/// Persists the user's scripts as JSON in Application Support, autosaving on every mutation.
///
/// The storage directory is injectable so tests can point at a temporary location.
@MainActor
@Observable
public final class ScriptStore {
    public private(set) var scripts: [Script]

    /// Last user-facing persistence error (e.g. a failed autosave), or `nil` when the most
    /// recent save succeeded. Surfaced in the editor so silent data loss is visible.
    public private(set) var lastError: String?

    /// Resolved path to the `scripts.json` file backing this store.
    public let fileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private static let logger = Logger(subsystem: Signposts.subsystem, category: "Store")

    /// Coalesces rapid mutations (e.g. per-keystroke edits in the editor) into a single
    /// disk write. `flush()` forces an immediate write for durability points (app quit).
    private var saveTask: Task<Void, Never>?
    private static let debounceInterval: Duration = .milliseconds(400)

    /// - Parameter directory: Directory in which to store `scripts.json`. When nil, the app's
    ///   Application Support directory (with a "TypeCue" subfolder) is used.
    public init(directory: URL? = nil) {
        let resolvedDirectory = ScriptStore.resolveDirectory(directory)
        ScriptStore.ensureDirectoryExists(resolvedDirectory)
        self.fileURL = resolvedDirectory.appendingPathComponent("scripts.json")
        let loaded = ScriptStore.load(from: fileURL, decoder: decoder)
        self.scripts = loaded.scripts
        self.lastError = loaded.error
    }

    // MARK: - Mutations

    public func addScript(_ script: Script) {
        scripts.append(script)
        scheduleSave()
    }

    /// Replaces an existing script matching `script.id`. No-op if not found.
    public func updateScript(_ script: Script) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        scheduleSave()
    }

    public func deleteScript(id: UUID) {
        let originalCount = scripts.count
        scripts.removeAll { $0.id == id }
        if scripts.count != originalCount {
            scheduleSave()
        }
    }

    /// Reorders a block within a single script. Indices are validated; out-of-range requests are ignored.
    public func moveBlock(inScriptID scriptID: UUID, from source: Int, to destination: Int) {
        guard let scriptIndex = scripts.firstIndex(where: { $0.id == scriptID }) else { return }
        var blocks = scripts[scriptIndex].blocks
        guard blocks.indices.contains(source) else { return }
        guard destination >= 0, destination < blocks.count else { return }
        let moved = blocks.remove(at: source)
        blocks.insert(moved, at: destination)
        scripts[scriptIndex].blocks = blocks
        scheduleSave()
    }

    // MARK: - Persistence

    /// Schedules a debounced write, coalescing bursts of mutations into one disk write.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            self?.writeToDisk()
        }
    }

    /// Forces an immediate write of any pending changes, cancelling the debounce timer.
    /// Call at durability points (app termination, window close) so a coalesced edit is
    /// never lost.
    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        writeToDisk()
    }

    private func writeToDisk() {
        let interval = Signposts.store.beginInterval("save")
        defer { Signposts.store.endInterval("save", interval) }
        do {
            let data = try encoder.encode(scripts)
            try data.write(to: fileURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = "Couldn't save your scripts: \(error.localizedDescription)"
            Self.logger.error("Failed to save scripts to \(self.fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    /// Re-reads `scripts.json`, replacing the in-memory scripts. Used by the
    /// `typecue://reload` command after an external tool (an AI agent or assistant, a
    /// script) edited the file. A pending debounced save is cancelled first so it can't
    /// overwrite the just-loaded external content; a failed decode keeps the current
    /// in-memory scripts rather than wiping a running session.
    public func reload() {
        saveTask?.cancel()
        saveTask = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            scripts = try decoder.decode([Script].self, from: data)
            lastError = nil
        } catch {
            lastError = "Couldn't reload your scripts file: \(error.localizedDescription)"
            Self.logger.error("Reload of \(self.fileURL.path, privacy: .public) failed; keeping in-memory scripts: \(String(describing: error), privacy: .public)")
        }
    }

    /// Loads scripts at init. A file that exists but fails to decode is moved aside
    /// (`scripts.json.corrupt-<timestamp>`) instead of being left in place - otherwise
    /// the next autosave would silently overwrite possibly-recoverable data with the
    /// empty list this returns.
    private static func load(from fileURL: URL, decoder: JSONDecoder) -> (scripts: [Script], error: String?) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ([], nil)
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return (try decoder.decode([Script].self, from: data), nil)
        } catch {
            logger.error("Failed to load scripts from \(fileURL.path, privacy: .public): \(String(describing: error), privacy: .public)")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let corruptURL = URL(fileURLWithPath: fileURL.path + ".corrupt-\(formatter.string(from: Date()))")
            do {
                try FileManager.default.moveItem(at: fileURL, to: corruptURL)
                return ([], "Couldn't read your scripts file - it was set aside as \(corruptURL.lastPathComponent) and TypeCue started with an empty list.")
            } catch {
                return ([], "Couldn't read your scripts file (\(fileURL.lastPathComponent)). TypeCue started with an empty list.")
            }
        }
    }

    private static func resolveDirectory(_ directory: URL?) -> URL {
        if let directory {
            return directory
        }
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupport.appendingPathComponent("TypeCue", isDirectory: true)
        } catch {
            logger.error("Failed to resolve Application Support directory; using temp: \(String(describing: error), privacy: .public)")
            return FileManager.default.temporaryDirectory.appendingPathComponent("TypeCue", isDirectory: true)
        }
    }

    private static func ensureDirectoryExists(_ directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create directory \(directory.path, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
