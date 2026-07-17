import Foundation

/// Pure presentation logic for the menu bar item's glyph.
///
/// Kept free of `AppKit`/`SwiftUI` and of the coordinator so the icon-selection rules -
/// including the transient warning flash that surfaces a blocked press during recording -
/// can be unit tested without a running app.
public enum MenuBarPresentation {
    /// What the status item shows: either an SF Symbol or a template image asset
    /// (the brand mark - blocks with the caret appearing when a script is armed).
    public enum Glyph: Equatable {
        case symbol(String)
        case asset(String)
    }

    /// A warning flash takes precedence over everything so a blocked press is visible
    /// even mid-recording; typing shows an in-progress symbol; otherwise the brand mark
    /// reflects the session - the caret is present exactly when a script is armed.
    /// Deliberately no continuous animation: users record their screens, and a blinking
    /// status item would end up in every take.
    public static func glyph(
        isFlashingWarning: Bool,
        isTyping: Bool,
        sessionState: SessionState
    ) -> Glyph {
        if isFlashingWarning { return .symbol("exclamationmark.triangle.fill") }
        if isTyping { return .symbol("ellipsis.circle") }
        switch sessionState {
        case .idle: return .asset("MenuBarIdle")
        case .armed: return .asset("MenuBarArmed")
        case .complete(let total): return total == 0 ? .asset("MenuBarIdle") : .symbol("checkmark.circle")
        }
    }
}
