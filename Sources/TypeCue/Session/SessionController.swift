import Foundation
import Observation

/// High-level status of a typing session, derived purely from the active script and cursor.
public enum SessionState: Equatable, Sendable {
    /// No active script selected.
    case idle
    /// Ready to type the block at `nextIndex` (0-based) out of `total` blocks.
    case armed(nextIndex: Int, total: Int)
    /// Every block has been typed (or the active script had no blocks).
    case complete(total: Int)
}

/// Pure cursor state machine over the active script.
///
/// Decides *which* block should be typed next; it never types anything itself. The set of blocks
/// for a given script id is supplied via an injected closure so this type stays decoupled from
/// `ScriptStore` (Phase 5 wires the closure to the store).
///
/// Semantics:
/// - An active script with zero blocks is defined as `.complete(total: 0)` — there is nothing to type.
/// - End-of-script behavior is STOP, not loop: after the final block is returned the state becomes
///   `.complete` and every subsequent `advance()` returns `nil` while remaining `.complete`.
/// - Switching the active script always resets the cursor to 0.
@MainActor
@Observable
public final class SessionController {
    public private(set) var activeScriptID: UUID?
    /// Index of the NEXT block to type (0-based).
    public private(set) var cursor: Int
    public private(set) var state: SessionState

    @ObservationIgnored private let blocksProvider: (UUID) -> [TextBlock]?

    public init(blocksProvider: @escaping (UUID) -> [TextBlock]?) {
        self.blocksProvider = blocksProvider
        self.activeScriptID = nil
        self.cursor = 0
        self.state = .idle
    }

    /// Sets (or clears) the active script, resets the cursor to 0, and recomputes state.
    public func setActiveScript(_ id: UUID?) {
        activeScriptID = id
        cursor = 0
        recomputeState()
    }

    /// Returns the block at the current cursor (if any) and advances the cursor by one.
    ///
    /// Returns `nil` when idle, when there are no blocks, or when already complete. Returns the last
    /// block on the call that reaches the end, then transitions to `.complete`.
    public func advance() -> TextBlock? {
        guard let blocks = currentBlocks(), !blocks.isEmpty else {
            recomputeState()
            return nil
        }
        guard cursor >= 0, cursor < blocks.count else {
            recomputeState()
            return nil
        }
        let block = blocks[cursor]
        cursor += 1
        recomputeState()
        return block
    }

    /// Re-arms the sequence: cursor back to 0 and state recomputed from the active script.
    public func reset() {
        cursor = 0
        recomputeState()
    }

    /// Moves the cursor back to `index` so that block re-arms. Used when a run is cancelled
    /// mid-block (the user pressed the shortcut again to stop): the interrupted block should
    /// be retyped on the next press, not silently skipped. The index is clamped to valid
    /// bounds so an out-of-range request can never crash or desync state.
    public func rewind(to index: Int) {
        guard let blocks = currentBlocks() else { return }
        cursor = max(0, min(index, blocks.count))
        recomputeState()
    }

    // MARK: - Private

    private func currentBlocks() -> [TextBlock]? {
        guard let activeScriptID else { return nil }
        return blocksProvider(activeScriptID)
    }

    private func recomputeState() {
        guard let blocks = currentBlocks() else {
            state = .idle
            return
        }
        let total = blocks.count
        if cursor >= total {
            state = .complete(total: total)
        } else {
            state = .armed(nextIndex: cursor, total: total)
        }
    }
}
