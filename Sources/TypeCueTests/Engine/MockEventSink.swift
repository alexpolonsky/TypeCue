import Foundation
import TypeCue

/// An ordered record of what the engine posted to its sink.
enum SinkCall: Equatable {
    case keystroke(Keystroke)
    case unicode(String)
}

/// Records sink calls in order. Thread-safe (calls may originate from the actor's
/// executor thread while the test reads from another).
final class MockEventSink: EventSink, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [SinkCall] = []

    var calls: [SinkCall] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func postKeystroke(_ keystroke: Keystroke) {
        lock.lock()
        recorded.append(.keystroke(keystroke))
        lock.unlock()
    }

    func postUnicode(_ string: String) {
        lock.lock()
        recorded.append(.unicode(string))
        lock.unlock()
    }
}
