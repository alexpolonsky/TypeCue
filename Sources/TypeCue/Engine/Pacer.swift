import Foundation

/// Computes the per-character delay for a typing run, optionally applying jitter.
///
/// Jitter draws from an injectable random source so tests can be deterministic.
public struct Pacer {
    public init() {}

    /// Per-character delay using an injectable generator (deterministic in tests).
    ///
    /// - jitter disabled: returns `baseDelay` (clamped to >= 0).
    /// - jitter enabled: returns a value in
    ///   `[baseDelay*(1-jitterFraction), baseDelay*(1+jitterFraction)]`, clamped to >= 0.
    public func delay(for config: PacingConfig, using generator: inout some RandomNumberGenerator) -> TimeInterval {
        guard config.jitterEnabled else { return max(0, config.baseDelay) }
        let sample = Double.random(in: 0...1, using: &generator)
        return delay(for: config, uniformSample: sample)
    }

    /// Convenience overload backed by the system RNG.
    public func delay(for config: PacingConfig) -> TimeInterval {
        var generator = SystemRandomNumberGenerator()
        return delay(for: config, using: &generator)
    }

    /// Compute the delay from a pre-drawn uniform sample in `[0, 1]`.
    ///
    /// Useful where an `inout` generator cannot cross an isolation boundary
    /// (e.g. inside an actor), letting the caller supply the randomness.
    public func delay(for config: PacingConfig, uniformSample: Double) -> TimeInterval {
        guard config.jitterEnabled else { return max(0, config.baseDelay) }
        let amplitude = max(0, config.baseDelay * config.jitterFraction)
        let jitter = (uniformSample * 2 - 1) * amplitude
        return max(0, config.baseDelay + jitter)
    }

    /// Per-character delay with natural rhythm: base jitter plus an occasional longer pause
    /// after the character that was just typed. Real typing slows at word and sentence
    /// boundaries, so a space earns a small extra beat, mid-sentence punctuation a larger
    /// one, and sentence-ending punctuation the largest. Both samples are in `[0, 1]` and
    /// injected so tests stay deterministic. When jitter is disabled this collapses to a
    /// constant `baseDelay` (no rhythm), matching the plain overloads.
    public func delay(
        for config: PacingConfig,
        afterCharacter character: Character?,
        jitterSample: Double,
        rhythmSample: Double
    ) -> TimeInterval {
        let base = delay(for: config, uniformSample: jitterSample)
        guard config.jitterEnabled, let character else { return base }

        let multiplier = Self.rhythmMultiplier(after: character)
        guard multiplier > 0 else { return base }

        // rhythmSample varies the extra beat from ~0 up to its max, so only *some*
        // boundaries get a noticeably longer pause - like a real person's uneven cadence.
        let extra = config.baseDelay * multiplier * rhythmSample
        return max(0, base + extra)
    }

    /// Extra-pause multiplier (in units of `baseDelay`) for the character just typed.
    private static func rhythmMultiplier(after character: Character) -> Double {
        switch character {
        case ".", "!", "?": return 6
        case ",", ";", ":": return 3
        case " ", "\n": return 1.5
        default: return 0
        }
    }
}
