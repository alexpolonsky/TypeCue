import Foundation

/// Visual state of a single block row in the floating panel, derived purely from the
/// session state and whether a block is currently being typed.
///
/// Kept separate from the view so the four-way distinction (already typed, currently
/// typing, next/armed, upcoming) is unit-testable without touching AppKit/SwiftUI.
public enum PanelRowState: Equatable, Sendable {
    /// Already typed on a previous press.
    case played
    /// Being typed into the focused field right now.
    case typing
    /// The next block that will type on the next press (armed).
    case next
    /// Not yet reached.
    case upcoming
}

/// Maps every block index to its `PanelRowState`.
///
/// Semantics mirror `SessionController`: `advance()` returns the block at the old cursor
/// and increments, so while `isTyping` the block *being* typed sits one index *behind*
/// the armed `nextIndex` (or is the final block when the session has already gone
/// `.complete`).
///
/// - Parameters:
///   - blockCount: Number of blocks in the active script.
///   - sessionState: Current session cursor state.
///   - isTyping: Whether the engine is mid-run on a block.
/// - Returns: One `PanelRowState` per block, in order. Empty when `blockCount <= 0`.
public func panelRowStates(
    blockCount: Int,
    sessionState: SessionState,
    isTyping: Bool
) -> [PanelRowState] {
    guard blockCount > 0 else { return [] }

    let typingIndex: Int? = {
        guard isTyping else { return nil }
        switch sessionState {
        case .armed(let nextIndex, _):
            let candidate = nextIndex - 1
            return candidate >= 0 ? candidate : nil
        case .complete(let total):
            return total > 0 ? total - 1 : nil
        case .idle:
            return nil
        }
    }()

    return (0..<blockCount).map { index in
        if index == typingIndex { return .typing }
        switch sessionState {
        case .idle:
            return .upcoming
        case .armed(let nextIndex, _):
            if index < nextIndex { return .played }
            if index == nextIndex { return .next }
            return .upcoming
        case .complete:
            return .played
        }
    }
}
