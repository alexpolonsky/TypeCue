import AppKit
import SwiftUI

/// Opens auxiliary windows (editor, settings, onboarding) for a menu bar app.
///
/// Menu bar apps (`LSUIElement`) have no standard window lifecycle, and opening SwiftUI
/// `Window` scenes programmatically from non-view code is awkward. Hosting SwiftUI views
/// in on-demand `NSWindow`s (created here) is the robust, fully controllable pattern.
@MainActor
final class WindowManager {
    private var windows: [String: NSWindow] = [:]

    /// Shows (or re-focuses) a window with the given id. Activates the app first (required
    /// for a menu bar app to bring a window forward), using the cooperative `activate()`
    /// rather than the deprecated, focus-stealing `ignoringOtherApps: true`. All callers are
    /// user-initiated (menu / first-run), so this never yanks focus during recording on its own.
    func show(
        id: String,
        title: String,
        size: NSSize,
        resizable: Bool = false,
        @ViewBuilder content: () -> some View
    ) {
        NSApp.activate()

        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.setContentSize(size)
        window.styleMask = resizable
            ? [.titled, .closable, .miniaturizable, .resizable]
            : [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
    }

    /// Closes (orders out) a managed window if it exists. The window is retained for reuse
    /// (`isReleasedWhenClosed = false`), so a later `show(id:)` re-focuses the same instance.
    func close(id: String) {
        windows[id]?.close()
    }
}
