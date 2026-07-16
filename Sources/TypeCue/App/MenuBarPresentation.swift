import Foundation

/// Pure presentation logic for the menu bar item's glyph.
///
/// Kept free of `AppKit`/`SwiftUI` and of the coordinator so the icon-selection rules -
/// including the transient warning flash that surfaces a blocked press during recording -
/// can be unit tested without a running app.
public enum MenuBarPresentation {
    /// SF Symbol for the menu bar item. A warning flash takes precedence over everything so
    /// a blocked press is visible even mid-recording; otherwise it reflects typing/session state.
    public static func symbol(
        isFlashingWarning: Bool,
        isTyping: Bool,
        sessionState: SessionState
    ) -> String {
        if isFlashingWarning { return "exclamationmark.triangle.fill" }
        if isTyping { return "ellipsis.circle" }
        switch sessionState {
        case .idle: return "keyboard"
        case .armed: return "arrowtriangle.right.circle"
        case .complete(let total): return total == 0 ? "keyboard" : "checkmark.circle"
        }
    }
}
