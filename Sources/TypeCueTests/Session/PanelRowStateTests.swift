import Testing
@testable import TypeCue

@Suite("PanelRowState")
struct PanelRowStateTests {
    @Test("Empty script yields no rows")
    func emptyScript() {
        #expect(panelRowStates(blockCount: 0, sessionState: .idle, isTyping: false).isEmpty)
        #expect(panelRowStates(blockCount: 0, sessionState: .complete(total: 0), isTyping: false).isEmpty)
    }

    @Test("Idle marks every row upcoming")
    func idleAllUpcoming() {
        let states = panelRowStates(blockCount: 3, sessionState: .idle, isTyping: false)
        #expect(states == [.upcoming, .upcoming, .upcoming])
    }

    @Test("Armed at start: first is next, rest upcoming")
    func armedAtStart() {
        let states = panelRowStates(blockCount: 3, sessionState: .armed(nextIndex: 0, total: 3), isTyping: false)
        #expect(states == [.next, .upcoming, .upcoming])
    }

    @Test("Armed mid-script: earlier played, current next, later upcoming")
    func armedMidScript() {
        let states = panelRowStates(blockCount: 4, sessionState: .armed(nextIndex: 2, total: 4), isTyping: false)
        #expect(states == [.played, .played, .next, .upcoming])
    }

    @Test("Typing a mid block marks it typing (one behind the armed index)")
    func typingMidBlock() {
        let states = panelRowStates(blockCount: 4, sessionState: .armed(nextIndex: 2, total: 4), isTyping: true)
        #expect(states == [.played, .typing, .next, .upcoming])
    }

    @Test("Typing the first block marks index 0 typing")
    func typingFirstBlock() {
        let states = panelRowStates(blockCount: 3, sessionState: .armed(nextIndex: 1, total: 3), isTyping: true)
        #expect(states == [.typing, .next, .upcoming])
    }

    @Test("Typing the last block: complete + typing marks final row typing")
    func typingLastBlock() {
        let states = panelRowStates(blockCount: 3, sessionState: .complete(total: 3), isTyping: true)
        #expect(states == [.played, .played, .typing])
    }

    @Test("Complete without typing marks every row played")
    func completeNotTyping() {
        let states = panelRowStates(blockCount: 3, sessionState: .complete(total: 3), isTyping: false)
        #expect(states == [.played, .played, .played])
    }

    @Test("Idle while isTyping is defensive: no typing row")
    func idleTypingDefensive() {
        let states = panelRowStates(blockCount: 2, sessionState: .idle, isTyping: true)
        #expect(states == [.upcoming, .upcoming])
    }
}
