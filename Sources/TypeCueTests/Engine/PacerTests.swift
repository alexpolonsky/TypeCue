import Testing
import TypeCue

/// Deterministic RNG (SplitMix64) so jitter tests are reproducible.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite("Pacer")
struct PacerTests {
    @Test("jitter disabled returns base delay")
    func jitterDisabledReturnsBaseDelay() {
        let pacer = Pacer()
        var generator = SeededGenerator(seed: 1)
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: false, jitterFraction: 0.4)
        #expect(pacer.delay(for: config, using: &generator) == 0.05)
    }

    @Test("jitter enabled stays within +/- jitterFraction bounds")
    func jitterWithinBounds() {
        let pacer = Pacer()
        var generator = SeededGenerator(seed: 42)
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0.4)
        let lower = config.baseDelay * (1 - config.jitterFraction)
        let upper = config.baseDelay * (1 + config.jitterFraction)

        for _ in 0..<1000 {
            let delay = pacer.delay(for: config, using: &generator)
            #expect(delay >= lower - 1e-12)
            #expect(delay <= upper + 1e-12)
        }
    }

    @Test("delay is never negative even with jitter larger than base")
    func neverNegative() {
        let pacer = Pacer()
        var generator = SeededGenerator(seed: 7)
        let config = PacingConfig(baseDelay: 0.01, jitterEnabled: true, jitterFraction: 2.0)

        for _ in 0..<1000 {
            #expect(pacer.delay(for: config, using: &generator) >= 0)
        }
    }

    @Test("uniform sample endpoints map to jitter bounds")
    func uniformSampleEndpoints() {
        let pacer = Pacer()
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0.4)
        #expect(abs(pacer.delay(for: config, uniformSample: 0) - 0.03) < 1e-12)
        #expect(abs(pacer.delay(for: config, uniformSample: 1) - 0.07) < 1e-12)
        #expect(abs(pacer.delay(for: config, uniformSample: 0.5) - 0.05) < 1e-12)
    }

    @Test("natural rhythm adds no extra pause after ordinary characters")
    func rhythmNoExtraForLetters() {
        let pacer = Pacer()
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0)
        let delay = pacer.delay(for: config, afterCharacter: "a", jitterSample: 0.5, rhythmSample: 1.0)
        #expect(abs(delay - 0.05) < 1e-12)
    }

    @Test("natural rhythm slows more at stronger boundaries")
    func rhythmBoundaryOrdering() {
        let pacer = Pacer()
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0)

        let space = pacer.delay(for: config, afterCharacter: " ", jitterSample: 0.5, rhythmSample: 1.0)
        let comma = pacer.delay(for: config, afterCharacter: ",", jitterSample: 0.5, rhythmSample: 1.0)
        let period = pacer.delay(for: config, afterCharacter: ".", jitterSample: 0.5, rhythmSample: 1.0)

        #expect(space > 0.05)
        #expect(comma > space)
        #expect(period > comma)
    }

    @Test("natural rhythm collapses to base delay when jitter disabled")
    func rhythmDisabledWhenJitterOff() {
        let pacer = Pacer()
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: false, jitterFraction: 0.4)
        let delay = pacer.delay(for: config, afterCharacter: ".", jitterSample: 0.9, rhythmSample: 1.0)
        #expect(delay == 0.05)
    }

    @Test("rhythmSample scales the extra pause")
    func rhythmSampleScales() {
        let pacer = Pacer()
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0)
        let none = pacer.delay(for: config, afterCharacter: ".", jitterSample: 0.5, rhythmSample: 0)
        let full = pacer.delay(for: config, afterCharacter: ".", jitterSample: 0.5, rhythmSample: 1.0)
        #expect(abs(none - 0.05) < 1e-12)
        #expect(full > none)
    }
}
