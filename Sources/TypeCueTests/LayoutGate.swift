import TypeCue

/// Some tests type Latin text through the real `KeystrokeResolver`, which resolves
/// against the live system keyboard layout. On a non-Latin active layout (e.g. Hebrew,
/// Cyrillic) those characters take the unicode-fallback path and per-keystroke
/// assertions don't apply. Those tests are gated on this check instead of failing:
/// switching the host machine's input source from a test is neither possible nor polite.
enum LayoutGate {
    static var latinTypable: Bool {
        if case .keystroke = KeystrokeResolver().resolve("a") { return true }
        return false
    }
}
