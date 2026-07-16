import Foundation

/// One ordered unit of scripted text that gets typed on a single hotkey press.
///
/// Speed and pauses are expressed inline in `text` via markers (see `BlockTokenizer`),
/// not as separate fields. Scripts saved by older versions used `speedOverride` /
/// `delayBefore` fields; those are migrated into leading markers on decode (see
/// `init(from:)`) and never written back out, so old scripts keep their behavior.
public struct TextBlock: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, speedOverride, delayBefore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let rawText = try container.decode(String.self, forKey: .text)
        let speedOverride = try container.decodeIfPresent(TimeInterval.self, forKey: .speedOverride)
        let delayBefore = try container.decodeIfPresent(TimeInterval.self, forKey: .delayBefore)
        self.text = TextBlock.migrate(text: rawText, speedOverride: speedOverride, delayBefore: delayBefore)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
    }

    /// Fold legacy per-block overrides into inline markers: a pre-block pause becomes a
    /// leading `[seconds]`, and a speed override wraps the text in `[speed:ms]…[speed:default]`.
    static func migrate(text: String, speedOverride: TimeInterval?, delayBefore: TimeInterval?) -> String {
        guard speedOverride != nil || (delayBefore ?? 0) > 0 else { return text }

        var prefix = ""
        var suffix = ""
        if let delayBefore, delayBefore > 0 {
            prefix += "[\(formatSeconds(delayBefore))]"
        }
        if let speedOverride {
            let milliseconds = Int((speedOverride * 1000).rounded())
            prefix += "[speed:\(milliseconds)]"
            suffix = "[speed:default]"
        }
        return prefix + text + suffix
    }

    private static func formatSeconds(_ value: TimeInterval) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
