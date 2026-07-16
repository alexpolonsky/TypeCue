import Foundation

/// Types an ordered list of `BlockSegment`s, strictly serially, one character at a time.
///
/// Serialization is provided by the actor. To guarantee two rapid hotkey presses never
/// interleave, a run in progress *rejects* a second concurrent `type(...)` call rather than
/// queuing it. (The app cancels the running task instead when the user presses again.)
public actor TypingEngine {
    public enum TypeOutcome: Equatable, Sendable {
        case completed
        case rejected
        case cancelled
    }

    private let sink: EventSink
    private let resolver: KeystrokeResolver
    private let pacer = Pacer()
    private let sleep: @Sendable (TimeInterval) async -> Void
    private let sampleUniform: @Sendable () -> Double
    private var isTyping = false

    /// - Parameters:
    ///   - sink: where resolved keystrokes / unicode fallbacks are posted.
    ///   - resolver: layout-aware character resolution.
    ///   - sampleUniform: draws a uniform value in `[0, 1]` for jitter/rhythm. Injectable
    ///     for deterministic tests. Passing randomness as a `@Sendable` closure avoids
    ///     moving an `inout RandomNumberGenerator` across the actor boundary.
    ///   - sleep: awaited between characters and for pauses. Injectable so tests run
    ///     instantly and can assert the timing budget.
    public init(
        sink: EventSink,
        resolver: KeystrokeResolver,
        sampleUniform: @escaping @Sendable () -> Double = { Double.random(in: 0...1) },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.sink = sink
        self.resolver = resolver
        self.sampleUniform = sampleUniform
        self.sleep = sleep
    }

    /// Convenience: type a raw string as a single literal text segment (no marker parsing).
    /// Used by the onboarding Test Pad, where the text should be typed verbatim.
    public func type(
        _ text: String,
        pacing: PacingConfig,
        newlineMode: NewlineMode = .shiftReturn
    ) async -> TypeOutcome {
        await type([.text(text)], pacing: pacing, newlineMode: newlineMode)
    }

    /// Type a tokenized block. Speed markers change the pace mid-run; pause markers sleep.
    public func type(
        _ segments: [BlockSegment],
        pacing: PacingConfig,
        newlineMode: NewlineMode = .shiftReturn
    ) async -> TypeOutcome {
        if isTyping { return .rejected }
        isTyping = true
        defer { isTyping = false }

        let runInterval = Signposts.typing.beginInterval("run")
        defer { Signposts.typing.endInterval("run", runInterval) }

        let startPacing = pacing
        var current = pacing

        for segment in segments {
            if Task.isCancelled { return .cancelled }

            switch segment {
            case .text(let string):
                for character in string {
                    if Task.isCancelled { return .cancelled }
                    Signposts.typing.emitEvent("char")
                    post(character, newlineMode: newlineMode)
                    await sleep(interCharacterDelay(current, after: character))
                }
            case .pressReturn:
                sink.postKeystroke(resolver.returnKeystroke(shifted: false))
                await sleep(interCharacterDelay(current, after: "\n"))
            case .pause(let seconds):
                await sleep(seconds)
            case .setSpeed(let secondsPerCharacter):
                current.baseDelay = secondsPerCharacter
            case .resetSpeed:
                current.baseDelay = startPacing.baseDelay
            }
        }

        return .completed
    }

    private func post(_ character: Character, newlineMode: NewlineMode) {
        if character == "\n" || character == "\r" {
            sink.postKeystroke(resolver.returnKeystroke(shifted: newlineMode.usesShift))
            return
        }
        switch resolver.resolve(character) {
        case .keystroke(let keystroke), .special(let keystroke):
            sink.postKeystroke(keystroke)
        case .unicode(let string):
            sink.postUnicode(string)
        }
    }

    private func interCharacterDelay(_ config: PacingConfig, after character: Character) -> TimeInterval {
        pacer.delay(
            for: config,
            afterCharacter: character,
            jitterSample: sampleUniform(),
            rhythmSample: sampleUniform()
        )
    }
}
