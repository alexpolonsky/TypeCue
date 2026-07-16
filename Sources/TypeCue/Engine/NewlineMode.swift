import Foundation

/// How a line break inside a block's text is typed.
///
/// In chat apps (Claude, Cursor, Slack, browsers) a plain Return usually *submits* the
/// message, so a multi-line block would send itself mid-way. `shiftReturn` inserts a line
/// break without submitting and behaves like a normal newline in plain text editors, which
/// is why it is the default.
public enum NewlineMode: String, Sendable, CaseIterable {
    /// Shift+Return: insert a line break without submitting. Default.
    case shiftReturn
    /// Plain Return: submits in most chat apps.
    case plainReturn

    public var usesShift: Bool { self == .shiftReturn }
}
