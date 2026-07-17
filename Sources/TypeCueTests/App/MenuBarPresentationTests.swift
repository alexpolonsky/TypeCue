import Testing
@testable import TypeCue

@Suite("MenuBarPresentation")
struct MenuBarPresentationTests {
    @Test("warning flash overrides typing and session state")
    func warningWins() {
        #expect(
            MenuBarPresentation.glyph(isFlashingWarning: true, isTyping: true, sessionState: .armed(nextIndex: 0, total: 3))
                == .symbol("exclamationmark.triangle.fill")
        )
        #expect(
            MenuBarPresentation.glyph(isFlashingWarning: true, isTyping: false, sessionState: .idle)
                == .symbol("exclamationmark.triangle.fill")
        )
    }

    @Test("typing shows the in-progress glyph when not flashing")
    func typingGlyph() {
        #expect(
            MenuBarPresentation.glyph(isFlashingWarning: false, isTyping: true, sessionState: .armed(nextIndex: 1, total: 4))
                == .symbol("ellipsis.circle")
        )
    }

    @Test("session state maps to the brand mark; the caret appears only while armed")
    func sessionGlyphs() {
        #expect(MenuBarPresentation.glyph(isFlashingWarning: false, isTyping: false, sessionState: .idle) == .asset("MenuBarIdle"))
        #expect(MenuBarPresentation.glyph(isFlashingWarning: false, isTyping: false, sessionState: .armed(nextIndex: 0, total: 2)) == .asset("MenuBarArmed"))
        #expect(MenuBarPresentation.glyph(isFlashingWarning: false, isTyping: false, sessionState: .complete(total: 0)) == .asset("MenuBarIdle"))
        #expect(MenuBarPresentation.glyph(isFlashingWarning: false, isTyping: false, sessionState: .complete(total: 3)) == .symbol("checkmark.circle"))
    }
}
