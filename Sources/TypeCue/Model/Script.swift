import Foundation

/// An ordered set of text blocks for a single demo recording.
public struct Script: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var blocks: [TextBlock]

    public init(id: UUID = UUID(), name: String, blocks: [TextBlock] = []) {
        self.id = id
        self.name = name
        self.blocks = blocks
    }

    /// A tutorial script seeded on first launch. Its blocks double as instructions and as
    /// a live demo of the typing engine: correctness (capitals, commas, symbols, numbers),
    /// speed and pause markers, multi-line blocks, and the [enter] marker. Experiencing it
    /// once is the fastest way to understand what the app does.
    public static func sample() -> Script {
        Script(
            name: "TypeCue tour",
            blocks: [
                TextBlock(text: "Focus any text field, then press your hotkey. [0.6] TypeCue types this line for you - one block per press, with real keystrokes."),
                TextBlock(text: "Markers direct the pace as it types: [0.8] that was a beat, [speed:22]this part races ahead,[speed:default] and now it settles back to your speed."),
                TextBlock(text: "A realistic prompt mixes them naturally. [0.5] Review this repo, [speed:120]slowly now - [speed:default]list the riskiest files, [0.6] and explain your reasoning as you go."),
                TextBlock(text: "Blocks can span lines too.\nThe break above was typed as Shift+Return, so chat apps hold the message. [0.5] Capitals, symbols, numbers - Hello, World! (v2 @ 100%) - all land exactly."),
                TextBlock(text: "End a block with the send marker and TypeCue presses Return for you.[enter]"),
                TextBlock(text: "That's the tour. [0.5] Edit these blocks, write your own script, or ask your AI agent to write one - see Formatting in the editor for every marker.")
            ]
        )
    }
}
