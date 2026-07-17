import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that types the next block of the active script. Default: Ctrl+Option+X.
    static let typeNextBlock = Self(
        "typeNextBlock",
        default: .init(.x, modifiers: [.control, .option])
    )
}
