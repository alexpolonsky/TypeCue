import AppKit
import Observation
import SwiftUI

/// Owns the floating script panel: a non-activating `NSPanel` that stays above other
/// apps without stealing focus, follows the user across Spaces, and can be dragged to any
/// monitor. Used as a glanceable teleprompter during recording.
///
/// Publishes `isVisible` so the menu label stays in sync no matter how the panel is
/// dismissed - the toggle, or the window's own red close button (handled via
/// `NSWindowDelegate.windowWillClose`).
@MainActor
@Observable
final class FloatingPanelController: NSObject, NSWindowDelegate {
    /// Persisted frame key so the panel remembers its last size and position across launches.
    @ObservationIgnored private static let frameAutosaveName = "TypeCueFloatingPanel"
    /// Teleprompter-friendly default: a tall, readable column of blocks.
    @ObservationIgnored private static let defaultSize = NSSize(width: 400, height: 560)

    private(set) var isVisible = false

    @ObservationIgnored private var panel: NSPanel?

    func toggle(coordinator: AppCoordinator) {
        if isVisible {
            hide()
        } else {
            show(coordinator: coordinator)
        }
    }

    func show(coordinator: AppCoordinator) {
        if let panel {
            panel.orderFrontRegardless()
            isVisible = true
            return
        }

        let hosting = NSHostingController(rootView: ScriptPanelView().environment(coordinator))
        let panel = NSPanel(
            // No `.utilityWindow`: that shrinks and dims the title bar, which made the
            // window controls read as greyed/inset. A plain titled panel gives a standard
            // close button.
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.title = "TypeCue"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        // Zoom and minimize are meaningless for an always-floating teleprompter in an
        // LSUIElement app (no Dock icon), so hide them rather than show them greyed out.
        // This leaves a single, standard-looking close button.
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true

        // Restore the remembered frame; only center on the very first show.
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        if !panel.setFrameUsingName(Self.frameAutosaveName) {
            panel.center()
        }

        self.panel = panel
        // orderFrontRegardless (not makeKey) keeps the user's current app frontmost.
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        // Release the panel and its NSHostingController while hidden so the SwiftUI view
        // tree and its retained state don't sit in memory for an always-running menu bar
        // app. The next show() recreates it; the frame is restored from the autosave name.
        panel = nil
        isVisible = false
    }

    // MARK: - NSWindowDelegate

    /// Closing via the red X doesn't route through `hide()`, so drive visibility from here
    /// too, and release the panel (same rationale as `hide()`).
    func windowWillClose(_ notification: Notification) {
        panel = nil
        isVisible = false
    }
}
