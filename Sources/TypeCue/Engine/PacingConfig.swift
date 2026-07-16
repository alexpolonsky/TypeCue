import Foundation

/// Human-like typing pacing. Delay is per character.
public struct PacingConfig: Equatable, Sendable {
    /// Base delay between characters, in seconds.
    public var baseDelay: TimeInterval
    /// When true, each character's delay is randomized within +/- jitterFraction of baseDelay.
    public var jitterEnabled: Bool
    /// Fraction (0...1) of baseDelay used as jitter amplitude.
    public var jitterFraction: Double

    public init(baseDelay: TimeInterval = 0.05, jitterEnabled: Bool = true, jitterFraction: Double = 0.4) {
        self.baseDelay = baseDelay
        self.jitterEnabled = jitterEnabled
        self.jitterFraction = jitterFraction
    }

    public static let `default` = PacingConfig()
}
