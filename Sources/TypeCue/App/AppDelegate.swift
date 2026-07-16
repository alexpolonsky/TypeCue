import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// True when the app is running only as the host for the unit-test bundle. In that
    /// case we skip all launch side effects (hotkey registration, opening windows), which
    /// would otherwise destabilize the headless test host. UI tests launch the app as a
    /// separate process without this env var, so they still get the full launch flow.
    private var isUnitTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isUnitTestHost else { return }
        let interval = Signposts.launch.beginInterval("post_main")
        AppCoordinator.shared.start()
        Signposts.launch.endInterval("post_main", interval)
    }

    /// Refresh permission state whenever the app is reactivated (e.g. after the user
    /// grants Accessibility in System Settings and switches back).
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !isUnitTestHost else { return }
        AppCoordinator.shared.permissions.refresh()
    }

    /// Flush any pending debounced script save so an edit made in the last fraction of a
    /// second before quitting is never lost.
    func applicationWillTerminate(_ notification: Notification) {
        guard !isUnitTestHost else { return }
        AppCoordinator.shared.store.flush()
    }
}
