import Foundation
import Observation

/// User-facing typing settings, persisted in `UserDefaults`.
///
/// Extracted from `AppCoordinator` so the coordinator no longer mixes settings
/// persistence with typing/window orchestration (single responsibility), and so the
/// settings load/save behavior is independently unit-testable with an injected
/// `UserDefaults` suite.
@MainActor
@Observable
public final class SettingsStore {
    public var baseDelay: TimeInterval {
        didSet { defaults.set(baseDelay, forKey: Keys.baseDelay) }
    }
    public var jitterEnabled: Bool {
        didSet { defaults.set(jitterEnabled, forKey: Keys.jitterEnabled) }
    }
    public var jitterFraction: Double {
        didSet { defaults.set(jitterFraction, forKey: Keys.jitterFraction) }
    }
    /// How line breaks inside a block are typed. Defaults to Shift+Return so multi-line
    /// blocks don't submit themselves in chat apps.
    public var newlineMode: NewlineMode {
        didSet { defaults.set(newlineMode.rawValue, forKey: Keys.newlineMode) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let baseDelay = "settings.baseDelay"
        static let jitterEnabled = "settings.jitterEnabled"
        static let jitterFraction = "settings.jitterFraction"
        static let newlineMode = "settings.newlineMode"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // didSet does not fire during initialization, so loading here never re-persists.
        self.baseDelay = defaults.object(forKey: Keys.baseDelay) as? TimeInterval ?? PacingConfig.default.baseDelay
        self.jitterEnabled = defaults.object(forKey: Keys.jitterEnabled) as? Bool ?? PacingConfig.default.jitterEnabled
        self.jitterFraction = defaults.object(forKey: Keys.jitterFraction) as? Double ?? PacingConfig.default.jitterFraction
        self.newlineMode = defaults.string(forKey: Keys.newlineMode).flatMap(NewlineMode.init(rawValue:)) ?? .shiftReturn
    }

    /// The current pacing configuration derived from the persisted settings.
    public var pacing: PacingConfig {
        PacingConfig(baseDelay: baseDelay, jitterEnabled: jitterEnabled, jitterFraction: jitterFraction)
    }
}
