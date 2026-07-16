import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that types the next block of the active script. Default: Ctrl+Option+T.
    static let typeNextBlock = Self(
        "typeNextBlock",
        default: .init(.t, modifiers: [.control, .option])
    )
}
