import Testing
@testable import TypeCue

@Suite("MenuBarPresentation")
struct MenuBarPresentationTests {
    @Test("warning flash overrides typing and session state")
    func warningWins() {
        #expect(
            MenuBarPresentation.symbol(isFlashingWarning: true, isTyping: true, sessionState: .armed(nextIndex: 0, total: 3))
                == "exclamationmark.triangle.fill"
        )
        #expect(
            MenuBarPresentation.symbol(isFlashingWarning: true, isTyping: false, sessionState: .idle)
                == "exclamationmark.triangle.fill"
        )
    }

    @Test("typing shows the in-progress glyph when not flashing")
    func typingGlyph() {
        #expect(
            MenuBarPresentation.symbol(isFlashingWarning: false, isTyping: true, sessionState: .armed(nextIndex: 1, total: 4))
                == "ellipsis.circle"
        )
    }

    @Test("session state maps to its glyph when idle and not flashing")
    func sessionGlyphs() {
        #expect(MenuBarPresentation.symbol(isFlashingWarning: false, isTyping: false, sessionState: .idle) == "keyboard")
        #expect(MenuBarPresentation.symbol(isFlashingWarning: false, isTyping: false, sessionState: .armed(nextIndex: 0, total: 2)) == "arrowtriangle.right.circle")
        #expect(MenuBarPresentation.symbol(isFlashingWarning: false, isTyping: false, sessionState: .complete(total: 0)) == "keyboard")
        #expect(MenuBarPresentation.symbol(isFlashingWarning: false, isTyping: false, sessionState: .complete(total: 3)) == "checkmark.circle")
    }
}
