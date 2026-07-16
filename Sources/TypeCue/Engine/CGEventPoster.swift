import CoreGraphics
import Foundation

/// Real `EventSink` implementation: posts genuine keyboard events into the system HID
/// event stream via `CGEventPost`. To a receiving app these are indistinguishable from
/// physical key presses. Requires Accessibility (PostEvent) permission to deliver events
/// to other apps; without it, `post` fails silently (see `PermissionManager`).
///
/// This mirrors the mechanism from the Raycast `clipboard-type` extension that the user
/// confirmed works, but runs in-process (no `osascript` spawn).
public final class CGEventPoster: EventSink, @unchecked Sendable {
    // `.privateState` gives this poster its own modifier-state tracking, isolated from the
    // real hardware/system state. Using `.hidSystemState` here caused a stuck-Shift bug:
    // posting a Shift-flagged character event blended `.maskShift` into the shared system
    // state, so every subsequently created event *inherited* Shift and the whole rest of
    // the text came out uppercase/shifted (e.g. "Hi, this" -> "HI< THIS"). A private source
    // never pollutes global state.
    private let source = CGEventSource(stateID: .privateState)

    /// Small gap between key-down and key-up. Back-to-back usually works, but a brief
    /// gap improves reliability in some Electron apps and terminals (documented CGEvent
    /// timing sensitivity). Cheap insurance on the reliability-critical path.
    private let keyDownUpGap: useconds_t

    public init(keyDownUpGapMicroseconds: useconds_t = 800) {
        self.keyDownUpGap = keyDownUpGapMicroseconds
    }

    public func postKeystroke(_ keystroke: Keystroke) {
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keystroke.keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keystroke.keyCode, keyDown: false)
        else { return }

        // Always set flags explicitly (including the empty case) so each event's modifiers
        // are absolute, never inherited from ambient/system state. This is what prevents a
        // Shift from one character leaking into the next.
        let flags: CGEventFlags = keystroke.needsShift ? .maskShift : []
        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        if keyDownUpGap > 0 { usleep(keyDownUpGap) }
        keyUp.post(tap: .cghidEventTap)
    }

    /// Fallback for characters not resolvable to a keystroke on the current layout
    /// (emoji, other scripts). Uses `keyboardSetUnicodeString` so the exact character is
    /// emitted regardless of layout. Uses the same Accessibility/PostEvent permission as
    /// `postKeystroke` (deliberately avoids AppleScript, which would trigger a second,
    /// separate Automation-consent prompt).
    public func postUnicode(_ string: String) {
        var buffer = Array(string.utf16)
        guard !buffer.isEmpty,
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        // Clear modifier flags so a preceding Shift can't corrupt the emitted unicode.
        keyDown.flags = []
        keyUp.flags = []

        keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: &buffer)
        keyUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: &buffer)

        keyDown.post(tap: .cghidEventTap)
        if keyDownUpGap > 0 { usleep(keyDownUpGap) }
        keyUp.post(tap: .cghidEventTap)
    }
}
