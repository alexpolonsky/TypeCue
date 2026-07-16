import Foundation
import Testing
@testable import TypeCue

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)")!
    }

    @Test("Loads PacingConfig defaults when nothing is persisted")
    func loadsDefaults() {
        let settings = SettingsStore(defaults: makeDefaults())
        #expect(settings.baseDelay == PacingConfig.default.baseDelay)
        #expect(settings.jitterEnabled == PacingConfig.default.jitterEnabled)
        #expect(settings.jitterFraction == PacingConfig.default.jitterFraction)
        #expect(settings.newlineMode == .shiftReturn)
    }

    @Test("Persists changes and reloads them in a fresh instance")
    func persistsAndReloads() {
        let defaults = makeDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.baseDelay = 0.123
        settings.jitterEnabled = false
        settings.jitterFraction = 0.4
        settings.newlineMode = .plainReturn

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.baseDelay == 0.123)
        #expect(reloaded.jitterEnabled == false)
        #expect(reloaded.jitterFraction == 0.4)
        #expect(reloaded.newlineMode == .plainReturn)
    }

    @Test("pacing reflects the current settings")
    func pacingReflectsSettings() {
        let settings = SettingsStore(defaults: makeDefaults())
        settings.baseDelay = 0.05
        settings.jitterEnabled = true
        settings.jitterFraction = 0.2
        #expect(settings.pacing == PacingConfig(baseDelay: 0.05, jitterEnabled: true, jitterFraction: 0.2))
    }
}
