import CoreGraphics

/// A single resolvable keystroke on the current keyboard layout.
public struct Keystroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public let needsShift: Bool

    public init(keyCode: CGKeyCode, needsShift: Bool) {
        self.keyCode = keyCode
        self.needsShift = needsShift
    }
}

/// Abstraction over the actual OS key-posting. Real impl (Phase 3) calls CGEventPost;
/// tests use a mock that records calls.
public protocol EventSink: AnyObject, Sendable {
    /// Post a genuine key down/up for a resolved keystroke.
    func postKeystroke(_ keystroke: Keystroke)
    /// Fallback for characters that cannot be resolved to a keystroke on the current
    /// layout (emoji, other scripts). Real impl types the unicode string directly.
    func postUnicode(_ string: String)
}
