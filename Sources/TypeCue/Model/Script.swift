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
                TextBlock(text: "Focus any text field, then press your hotkey. TypeCue types this line for you, one block per press."),
                TextBlock(text: "You can shift speed mid-line: [speed:20]this part races by,[speed:default] then [speed:120]this part crawls.[speed:default]"),
                TextBlock(text: "Add pauses for dramatic timing.[1.5] That was a one-and-a-half second beat before this sentence."),
                TextBlock(text: "This block spans two lines.\nThe break was inserted with Shift+Return, so it won't send early in chat apps."),
                TextBlock(text: "Capitals, commas, symbols and numbers all land exactly: Hello, World! (v2 @ 100%)."),
                TextBlock(text: "Finish a prompt, then let TypeCue send it for you.[enter]"),
                TextBlock(text: "That's the tour. Edit these blocks, delete this script, or write your own. Open Formatting in the editor for every marker.")
            ]
        )
    }
}
