import Testing
import TypeCue

/// These assertions are intentionally structural / layout-robust: they never assert
/// concrete keycode numbers, only relationships that must hold on any Latin layout
/// (which the dev machine's current input source provides).
@Suite("KeystrokeResolver")
struct KeystrokeResolverTests {
    @Test("uppercase shares the base keycode but needs shift")
    func uppercaseSharesKeycode() {
        let resolver = KeystrokeResolver()

        // On a non-Latin active layout (e.g. Hebrew) Latin letters take the unicode
        // fallback and this keystroke assertion doesn't apply - pass vacuously. The
        // probe must happen here, in the test, because the host machine's input
        // source can change between test discovery and execution.
        guard case let .keystroke(lower) = resolver.resolve("a"),
              case let .keystroke(upper) = resolver.resolve("A") else {
            return
        }

        #expect(lower.needsShift == false)
        #expect(upper.needsShift == true)
        #expect(lower.keyCode == upper.keyCode)
    }

    @Test("newline, tab and space resolve to special keystrokes")
    func whitespaceIsSpecial() {
        let resolver = KeystrokeResolver()
        #expect(isSpecial(resolver.resolve("\n")))
        #expect(isSpecial(resolver.resolve("\r")))
        #expect(isSpecial(resolver.resolve("\t")))
        #expect(isSpecial(resolver.resolve(" ")))
    }

    @Test("non-typable character falls back to unicode")
    func emojiFallsBackToUnicode() {
        let resolver = KeystrokeResolver()

        guard case let .unicode(string) = resolver.resolve("😀") else {
            Issue.record("expected emoji to resolve to unicode fallback")
            return
        }
        #expect(string == "😀")
    }

    private func isSpecial(_ resolution: KeystrokeResolver.Resolution) -> Bool {
        if case .special = resolution { return true }
        return false
    }
}
