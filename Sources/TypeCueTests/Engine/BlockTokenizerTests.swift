import Testing
import TypeCue

@Suite("BlockTokenizer")
struct BlockTokenizerTests {
    @Test("plain text with no markers is a single text segment")
    func plainText() {
        #expect(BlockTokenizer.tokenize("hello world") == [.text("hello world")])
    }

    @Test("empty input produces no segments")
    func emptyInput() {
        #expect(BlockTokenizer.tokenize("") == [])
    }

    @Test("speed marker parses milliseconds into seconds")
    func speedMarker() {
        #expect(BlockTokenizer.tokenize("[speed:20]") == [.setSpeed(0.02)])
        #expect(BlockTokenizer.tokenize("[speed:100]") == [.setSpeed(0.1)])
    }

    @Test("speed:default resets speed")
    func speedDefault() {
        #expect(BlockTokenizer.tokenize("[speed:default]") == [.resetSpeed])
    }

    @Test("numeric marker parses as a pause in seconds")
    func pauseMarker() {
        #expect(BlockTokenizer.tokenize("[0.5]") == [.pause(0.5)])
        #expect(BlockTokenizer.tokenize("[2]") == [.pause(2)])
    }

    @Test("enter marker presses return")
    func enterMarker() {
        #expect(BlockTokenizer.tokenize("[enter]") == [.pressReturn])
    }

    @Test("markers are case-insensitive")
    func caseInsensitive() {
        #expect(BlockTokenizer.tokenize("[ENTER]") == [.pressReturn])
        #expect(BlockTokenizer.tokenize("[Speed:Default]") == [.resetSpeed])
        #expect(BlockTokenizer.tokenize("[SPEED:50]") == [.setSpeed(0.05)])
    }

    @Test("markers interleave with surrounding text in order")
    func interleaved() {
        let segments = BlockTokenizer.tokenize("Hi[0.5]there[speed:20]fast[speed:default]done")
        #expect(segments == [
            .text("Hi"),
            .pause(0.5),
            .text("there"),
            .setSpeed(0.02),
            .text("fast"),
            .resetSpeed,
            .text("done")
        ])
    }

    @Test("unrecognized bracket content is kept literally")
    func unrecognizedLiteral() {
        #expect(BlockTokenizer.tokenize("[hello]") == [.text("[hello]")])
        #expect(BlockTokenizer.tokenize("array[0] = x") == [.text("array[0] = x")])
    }

    @Test("zero-second pause is treated as literal, not a no-op pause")
    func zeroPauseIsLiteral() {
        #expect(BlockTokenizer.tokenize("[0]") == [.text("[0]")])
    }

    @Test("negative numbers are not markers")
    func negativeNotMarker() {
        #expect(BlockTokenizer.tokenize("[-1]") == [.text("[-1]")])
        #expect(BlockTokenizer.tokenize("[speed:-5]") == [.text("[speed:-5]")])
    }

    @Test("unclosed bracket is literal text")
    func unclosedBracket() {
        #expect(BlockTokenizer.tokenize("a [ b") == [.text("a [ b")])
        #expect(BlockTokenizer.tokenize("[speed:20") == [.text("[speed:20")])
    }

    @Test("empty brackets are literal")
    func emptyBrackets() {
        #expect(BlockTokenizer.tokenize("[]") == [.text("[]")])
    }

    @Test("newlines inside text are preserved in the text segment")
    func newlinesPreserved() {
        #expect(BlockTokenizer.tokenize("line1\nline2") == [.text("line1\nline2")])
    }
}
