import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Observation

/// Tracks and guides the one permission TypeCue needs: Accessibility (to post synthetic
/// keystrokes to other apps). Also exposes secure-input detection so the app can warn
/// instead of failing silently when a password field is focused.
@MainActor
@Observable
public final class PermissionManager {
    /// Whether the process is currently a trusted Accessibility client.
    ///
    /// Note: `AXIsProcessTrusted()` can return `true` before the permission is fully
    /// functional right after granting (documented macOS quirk). The onboarding flow
    /// therefore also offers a functional "test type" check rather than trusting this
    /// flag alone.
    public private(set) var isTrusted: Bool

    public init() {
        self.isTrusted = AXIsProcessTrusted()
    }

    /// Re-read the current trust state (e.g. when the app becomes active again after the
    /// user visited System Settings).
    public func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Triggers the system Accessibility permission prompt if not yet granted. The prompt
    /// can only be shown once per app install; afterwards the user must toggle it in
    /// System Settings, so pair this with `openAccessibilitySettings()`.
    public func requestAccessibilityPrompt() {
        // Key value of `kAXTrustedCheckOptionPrompt`; referenced by literal to avoid
        // Swift 6 strict-concurrency issues with the imported C global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    /// Opens System Settings directly at Privacy & Security > Accessibility.
    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    /// True when a secure input field (e.g. a password field) currently has focus. macOS
    /// blocks all synthetic keystrokes system-wide in this state; the app should surface a
    /// "type manually" indicator rather than silently dropping the text.
    public static var isSecureInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }
}
