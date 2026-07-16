import Foundation
import Testing
@testable import TypeCue

@Suite("Script.sample")
struct ScriptSampleTests {
    private var blocks: [TextBlock] { Script.sample().blocks }
    private var joined: String { blocks.map(\.text).joined(separator: "\n") }

    @Test("each marker family is demonstrated")
    func coversMarkers() {
        let all = joined
        #expect(all.contains("[speed:"))
        #expect(all.contains("[speed:default]"))
        #expect(all.contains("[enter]"))
        // A multi-line block (Shift+Return authoring) contains a raw newline.
        #expect(blocks.contains { $0.text.contains("\n") })
        // A numeric pause marker like [1.5] tokenizes to a pause segment.
        let hasPause = blocks.contains { block in
            BlockTokenizer.tokenize(block.text).contains { segment in
                if case .pause = segment { return true }
                return false
            }
        }
        #expect(hasPause)
    }

    @Test("no em dashes in sample copy")
    func noEmDashes() {
        #expect(!joined.contains("\u{2014}"))
    }

    @Test("blocks each demonstrate a distinct capability")
    func distinctBlocks() {
        #expect(blocks.count >= 6)
        #expect(blocks.allSatisfy { !$0.text.isEmpty })
    }
}
