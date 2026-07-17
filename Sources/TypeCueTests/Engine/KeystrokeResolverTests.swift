import Testing
import TypeCue

/// These assertions are intentionally structural / layout-robust: they never assert
/// concrete keycode numbers, only relationships that must hold on any Latin layout
/// (which the dev machine's current input source provides).
@Suite("KeystrokeResolver")
struct KeystrokeResolverTests {
    @Test(
        "uppercase shares the base keycode but needs shift",
        .enabled(if: LayoutGate.latinTypable, "Requires a Latin-capable active keyboard layout (switch to English/ABC)")
    )
    func uppercaseSharesKeycode() {
        let resolver = KeystrokeResolver()

        guard case let .keystroke(lower) = resolver.resolve("a") else {
            Issue.record("expected 'a' to resolve to a keystroke on this layout")
            return
        }
        guard case let .keystroke(upper) = resolver.resolve("A") else {
            Issue.record("expected 'A' to resolve to a keystroke on this layout")
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
