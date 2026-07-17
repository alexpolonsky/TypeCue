import Foundation
import Testing
import TypeCue

/// A controllable gate used as the engine's injected `sleep`. It lets a test hold a
/// run suspended (inside `sleep`) while it issues a second, concurrent `type()` call,
/// then release it deterministically.
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
    private var arrivedCount = 0

    /// Called by the engine's injected sleep. Suspends until the gate is opened.
    func wait() async {
        arrivedCount += 1
        for continuation in arrivalWaiters { continuation.resume() }
        arrivalWaiters.removeAll()

        if isOpen { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    /// Resolves once at least `minimum` callers have reached `wait()`.
    func waitForArrival(minimum: Int = 1) async {
        if arrivedCount >= minimum { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            arrivalWaiters.append(continuation)
        }
    }

    /// Opens the gate: resumes all current waiters and lets future waits pass through.
    func open() {
        isOpen = true
        for continuation in waiters { continuation.resume() }
        waiters.removeAll()
    }
}

/// Sums the durations passed to the engine's injected sleep.
private actor DurationRecorder {
    private(set) var total: TimeInterval = 0

    func add(_ seconds: TimeInterval) {
        total += seconds
    }
}

@Suite("TypingEngine")
struct TypingEngineTests {
    private func expectedCall(for character: Character, resolver: KeystrokeResolver) -> SinkCall {
        switch resolver.resolve(character) {
        case .keystroke(let keystroke), .special(let keystroke):
            return .keystroke(keystroke)
        case .unicode(let string):
            return .unicode(string)
        }
    }

    @Test("types characters in order")
    func typesInOrder() async {
        let sink = MockEventSink()
        let resolver = KeystrokeResolver()
        let engine = TypingEngine(
            sink: sink,
            resolver: resolver,
            sampleUniform: { 0.5 },
            sleep: { _ in }
        )
        let config = PacingConfig(baseDelay: 0, jitterEnabled: false, jitterFraction: 0)

        let outcome = await engine.type("ab", pacing: config)

        #expect(outcome == .completed)
        let expected = Array("ab").map { expectedCall(for: $0, resolver: resolver) }
        #expect(sink.calls == expected)
    }

    /// Regression test: two rapid presses must never interleave. The second call, made
    /// while the first is still running, is rejected and produces no sink calls.
    @Test("concurrent type is rejected and never interleaves")
    func concurrentTypeIsRejected() async {
        let sink = MockEventSink()
        let resolver = KeystrokeResolver()
        let gate = Gate()
        let engine = TypingEngine(
            sink: sink,
            resolver: resolver,
            sampleUniform: { 0.5 },
            sleep: { _ in await gate.wait() }
        )
        let config = PacingConfig(baseDelay: 0, jitterEnabled: false, jitterFraction: 0)

        // First run posts its first character, then suspends inside the gate.
        let first = Task { await engine.type("ab", pacing: config) }
        await gate.waitForArrival()

        // Second call arrives while the first run is held open.
        let second = await engine.type("cd", pacing: config)
        #expect(second == .rejected)

        // Release the first run and let it finish.
        await gate.open()
        let firstOutcome = await first.value
        #expect(firstOutcome == .completed)

        // Exactly one run's worth of calls — no interleaving.
        let expected = Array("ab").map { expectedCall(for: $0, resolver: resolver) }
        #expect(sink.calls == expected)
    }

    @Test("total delay equals character count times base delay when jitter disabled")
    func timingBudget() async {
        let sink = MockEventSink()
        let resolver = KeystrokeResolver()
        // Per-character sleep accounting assumes Latin chars resolve to keystrokes;
        // on a non-Latin active layout they batch through the unicode path instead.
        // Probe here (not in a trait) - the input source can change at any moment.
        guard case .keystroke = resolver.resolve("h") else { return }
        let recorder = DurationRecorder()
        let engine = TypingEngine(
            sink: sink,
            resolver: resolver,
            sampleUniform: { 0.5 },
            sleep: { seconds in await recorder.add(seconds) }
        )
        let base: TimeInterval = 0.05
        let config = PacingConfig(baseDelay: base, jitterEnabled: false, jitterFraction: 0.4)
        let text = "hello"

        let outcome = await engine.type(text, pacing: config)
        #expect(outcome == .completed)

        let total = await recorder.total
        #expect(abs(total - Double(text.count) * base) < 1e-9)
    }

    @Test("pause segment adds its full duration to the timing budget")
    func pauseSegmentTiming() async {
        let sink = MockEventSink()
        let recorder = DurationRecorder()
        let engine = TypingEngine(
            sink: sink,
            resolver: KeystrokeResolver(),
            sampleUniform: { 0.5 },
            sleep: { seconds in await recorder.add(seconds) }
        )
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: false, jitterFraction: 0)

        let outcome = await engine.type([.text("a"), .pause(1.0), .text("b")], pacing: config)
        #expect(outcome == .completed)

        // 0.05 after 'a' + 1.0 pause + 0.05 after 'b'
        let total = await recorder.total
        #expect(abs(total - 1.1) < 1e-9)
    }

    @Test("setSpeed changes pace mid-run and resetSpeed restores it")
    func speedMarkersChangePace() async {
        let sink = MockEventSink()
        let recorder = DurationRecorder()
        let engine = TypingEngine(
            sink: sink,
            resolver: KeystrokeResolver(),
            sampleUniform: { 0.5 },
            sleep: { seconds in await recorder.add(seconds) }
        )
        let config = PacingConfig(baseDelay: 0.05, jitterEnabled: false, jitterFraction: 0)

        // 'a' at 0.05, then speed 0.2 for 'b', then reset for 'c'.
        let outcome = await engine.type(
            [.text("a"), .setSpeed(0.2), .text("b"), .resetSpeed, .text("c")],
            pacing: config
        )
        #expect(outcome == .completed)

        let total = await recorder.total
        #expect(abs(total - (0.05 + 0.2 + 0.05)) < 1e-9)
    }

    @Test("pressReturn posts a plain Return regardless of newline mode")
    func pressReturnPostsPlainReturn() async {
        let sink = MockEventSink()
        let resolver = KeystrokeResolver()
        let engine = TypingEngine(
            sink: sink,
            resolver: resolver,
            sampleUniform: { 0.5 },
            sleep: { _ in }
        )
        let config = PacingConfig(baseDelay: 0, jitterEnabled: false, jitterFraction: 0)

        let outcome = await engine.type([.pressReturn], pacing: config, newlineMode: .shiftReturn)
        #expect(outcome == .completed)
        #expect(sink.calls == [.keystroke(resolver.returnKeystroke(shifted: false))])
    }

    @Test("newline uses Shift+Return in shiftReturn mode and plain Return otherwise")
    func newlineModeControlsShift() async {
        let resolver = KeystrokeResolver()

        func middleCall(mode: NewlineMode) async -> SinkCall {
            let sink = MockEventSink()
            let engine = TypingEngine(
                sink: sink,
                resolver: resolver,
                sampleUniform: { 0.5 },
                sleep: { _ in }
            )
            let config = PacingConfig(baseDelay: 0, jitterEnabled: false, jitterFraction: 0)
            _ = await engine.type([.text("a\nb")], pacing: config, newlineMode: mode)
            return sink.calls[1]
        }

        let shifted = await middleCall(mode: .shiftReturn)
        #expect(shifted == .keystroke(resolver.returnKeystroke(shifted: true)))

        let plain = await middleCall(mode: .plainReturn)
        #expect(plain == .keystroke(resolver.returnKeystroke(shifted: false)))
    }

    @Test("cancellation stops the run")
    func cancellationStopsRun() async {
        let sink = MockEventSink()
        let resolver = KeystrokeResolver()
        let gate = Gate()
        let engine = TypingEngine(
            sink: sink,
            resolver: resolver,
            sampleUniform: { 0.5 },
            sleep: { _ in await gate.wait() }
        )
        let config = PacingConfig(baseDelay: 0, jitterEnabled: false, jitterFraction: 0)

        let run = Task { await engine.type("abcdef", pacing: config) }
        await gate.waitForArrival()

        run.cancel()
        await gate.open()

        let outcome = await run.value
        #expect(outcome == .cancelled)
    }
}
