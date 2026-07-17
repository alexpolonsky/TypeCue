import os

/// Centralized `OSSignposter` instances for performance instrumentation.
///
/// Intervals defined here back the app's performance measurement protocol
/// (launch, typing run/char, store save, panel body). Capture baselines in Release
/// with Instruments (Time Profiler / App Launch / SwiftUI / Energy Log) against the
/// signpost categories below before optimizing any hot path.
enum Signposts {
    static let subsystem = "com.alexpo.typecue"

    /// App launch and coordinator initialization.
    static let launch = OSSignposter(subsystem: subsystem, category: "Launch")
    /// The typing run and per-character emission.
    static let typing = OSSignposter(subsystem: subsystem, category: "Typing")
    /// Script persistence (disk writes).
    static let store = OSSignposter(subsystem: subsystem, category: "Store")
    /// SwiftUI body evaluations (debug-only signal for re-render hygiene).
    static let ui = OSSignposter(subsystem: subsystem, category: "UI")
}
