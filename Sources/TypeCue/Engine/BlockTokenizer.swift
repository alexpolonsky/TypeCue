import Foundation

/// One typed unit produced by parsing a block's text.
///
/// A block is authored as plain text with optional inline markers (`[speed:20]`, `[0.5]`,
/// `[enter]`, `[speed:default]`). `BlockTokenizer` turns that text into an ordered list of
/// these segments, which `TypingEngine` then plays back.
public enum BlockSegment: Equatable, Sendable {
    /// Literal text, typed character by character.
    case text(String)
    /// Pause for this many seconds before continuing.
    case pause(TimeInterval)
    /// Change the per-character speed for the rest of the block (seconds per character).
    case setSpeed(TimeInterval)
    /// Restore the per-character speed to the run's starting speed.
    case resetSpeed
    /// Press Return once (always a real Return, regardless of the global line-break mode).
    case pressReturn
}

/// Parses a block's text into an ordered list of `BlockSegment`s.
///
/// Marker syntax (case-insensitive keywords):
/// - `[speed:20]`   -> `.setSpeed(0.02)`  (milliseconds per character)
/// - `[speed:default]` -> `.resetSpeed`
/// - `[0.5]`, `[2]` -> `.pause(seconds)`
/// - `[enter]`      -> `.pressReturn`
///
/// Anything inside brackets that is not a recognized marker (e.g. `[hello]`) is typed
/// literally, brackets included. An unclosed `[` is also typed literally.
public enum BlockTokenizer {
    public static func tokenize(_ input: String) -> [BlockSegment] {
        var segments: [BlockSegment] = []
        var buffer = ""
        let chars = Array(input)
        var i = 0

        func flushText() {
            if !buffer.isEmpty {
                segments.append(.text(buffer))
                buffer = ""
            }
        }

        while i < chars.count {
            let char = chars[i]
            guard char == "[", let close = indexOfClosingBracket(chars, from: i + 1) else {
                buffer.append(char)
                i += 1
                continue
            }

            let content = String(chars[(i + 1)..<close])
            if let segment = marker(for: content) {
                flushText()
                segments.append(segment)
                i = close + 1
            } else {
                // Not a recognized marker: emit "[" literally and re-scan the rest so the
                // whole "[content]" survives as plain text.
                buffer.append("[")
                i += 1
            }
        }

        flushText()
        return segments
    }

    /// Index of the first `]` after `start`, or `nil` if another `[` appears first or none
    /// is found (in which case the opening `[` is treated as a literal).
    private static func indexOfClosingBracket(_ chars: [Character], from start: Int) -> Int? {
        var j = start
        while j < chars.count {
            if chars[j] == "]" { return j }
            if chars[j] == "[" { return nil }
            j += 1
        }
        return nil
    }

    private static func marker(for content: String) -> BlockSegment? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        if lowered == "enter" { return .pressReturn }
        if lowered == "speed:default" { return .resetSpeed }
        if lowered.hasPrefix("speed:") {
            let value = trimmed.dropFirst("speed:".count).trimmingCharacters(in: .whitespaces)
            if let milliseconds = Double(value), milliseconds >= 0 {
                return .setSpeed(milliseconds / 1000)
            }
            return nil
        }
        // Strictly positive: a zero pause is a no-op, and treating "[0]" as literal keeps
        // common array-index text (e.g. "items[0]") from being silently swallowed.
        if let seconds = Double(trimmed), seconds > 0 {
            return .pause(seconds)
        }
        return nil
    }
}
