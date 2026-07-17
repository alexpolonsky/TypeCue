import AppKit
import CoreGraphics
import Sauce

/// Layout-aware `Character` -> `Keystroke` resolution.
///
/// Builds a cache of printable characters for the *current* keyboard layout via
/// Sauce, and rebuilds it whenever the active layout / input source changes.
/// Special whitespace characters resolve to layout-independent special keys, and
/// anything unresolvable falls back to unicode string entry.
public final class KeystrokeResolver: @unchecked Sendable {
    public enum Resolution: Equatable {
        case keystroke(Keystroke)
        case special(Keystroke)
        case unicode(String)
    }

    /// Printable physical keys enumerated to build the layout cache.
    private static let printableKeys: [Key] = [
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
        .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
        .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine,
        .minus, .equal, .leftBracket, .rightBracket, .backslash,
        .semicolon, .quote, .comma, .period, .slash, .grave
    ]

    private let lock = NSLock()
    private var cache: [Character: Keystroke] = [:]
    private var observer: NSObjectProtocol?

    public init() {
        // Defer the (nontrivial) layout enumeration off the synchronous launch path.
        // Kept on the main actor because Sauce/TIS input-source APIs are main-thread
        // affine; this runs on the next main run-loop pass, long before any hotkey.
        DispatchQueue.main.async { [weak self] in
            self?.rebuildCache()
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.SauceSelectedKeyboardKeyCodesChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.rebuildCache()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Runs Sauce/TIS work on the main thread. The Text Input Sources APIs underneath
    /// Sauce are main-thread affine and ABORT the process when reached from two threads
    /// concurrently; the typing engine (and tests) may call `resolve` off-main, so every
    /// Sauce touchpoint funnels through here.
    private func onMain<T>(_ work: () -> T) -> T {
        if Thread.isMainThread { return work() }
        return DispatchQueue.main.sync(execute: work)
    }

    /// The Return keystroke on the current layout. `shifted` posts Shift+Return, which
    /// inserts a line break without submitting in most chat apps.
    public func returnKeystroke(shifted: Bool) -> Keystroke {
        Keystroke(keyCode: onMain { CGKeyCode(Sauce.shared.keyCode(for: .`return`)) }, needsShift: shifted)
    }

    public func resolve(_ character: Character) -> Resolution {
        switch character {
        case "\n", "\r":
            return .special(Keystroke(keyCode: onMain { CGKeyCode(Sauce.shared.keyCode(for: .`return`)) }, needsShift: false))
        case "\t":
            return .special(Keystroke(keyCode: onMain { CGKeyCode(Sauce.shared.keyCode(for: .tab)) }, needsShift: false))
        case " ":
            return .special(Keystroke(keyCode: onMain { CGKeyCode(Sauce.shared.keyCode(for: .space)) }, needsShift: false))
        default:
            break
        }

        ensureCacheBuilt()

        lock.lock()
        let cached = cache[character]
        lock.unlock()

        if let cached {
            return .keystroke(cached)
        }
        return .unicode(String(character))
    }

    /// Builds the layout cache on first use if the launch-time warm-up hasn't run yet.
    /// Idempotent, so the rare race between first `resolve` and the deferred warm-up is
    /// harmless (worst case: the cache is built once here instead).
    private func ensureCacheBuilt() {
        lock.lock()
        let needsBuild = cache.isEmpty
        lock.unlock()
        if needsBuild { rebuildCache() }
    }

    private func rebuildCache() {
        let newCache = onMain { () -> [Character: Keystroke] in
            var built: [Character: Keystroke] = [:]

            // First pass: base (unshifted) mappings take priority.
            for key in Self.printableKeys {
                let keyCode = Sauce.shared.keyCode(for: key)
                guard let base = Sauce.shared.character(for: Int(keyCode), cocoaModifiers: []),
                      base.count == 1, let character = base.first else { continue }
                if built[character] == nil {
                    built[character] = Keystroke(keyCode: keyCode, needsShift: false)
                }
            }

            // Second pass: shifted mappings, never overwriting an existing base mapping.
            for key in Self.printableKeys {
                let keyCode = Sauce.shared.keyCode(for: key)
                guard let shifted = Sauce.shared.character(for: Int(keyCode), cocoaModifiers: [.shift]),
                      shifted.count == 1, let character = shifted.first else { continue }
                if built[character] == nil {
                    built[character] = Keystroke(keyCode: keyCode, needsShift: true)
                }
            }
            return built
        }

        lock.lock()
        cache = newCache
        lock.unlock()
    }
}
