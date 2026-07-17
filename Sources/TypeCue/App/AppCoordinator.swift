import AppKit
import Foundation
import KeyboardShortcuts
import Observation
import SwiftUI

/// Central wiring for the app: owns the store, session state machine, typing engine,
/// event poster, permissions, and auxiliary windows. Registers the global hotkey and
/// drives the "type next block" flow.
@MainActor
@Observable
final class AppCoordinator {
    static let shared = AppCoordinator()

    let store: ScriptStore
    let session: SessionController
    let settings: SettingsStore
    let permissions = PermissionManager()
    let windows = WindowManager()
    let floatingPanel = FloatingPanelController()

    @ObservationIgnored private let poster = CGEventPoster()
    @ObservationIgnored private let engine: TypingEngine

    // MARK: - Transient UI state

    private(set) var isTyping = false
    /// A short, human-readable warning surfaced in the menu (e.g. secure input active).
    var warning: String?
    /// True for a brief window after a blocked press, so the menu bar icon and the floating
    /// panel can flash the warning actively - the menu dropdown alone is invisible mid-recording.
    private(set) var isFlashingWarning = false
    @ObservationIgnored private var warningFlashTask: Task<Void, Never>?
    /// Which tab the unified main window shows. Set before opening so switching works even
    /// when the window is already on screen.
    var editorTab: EditorTab = .scripts
    /// Which onboarding step is shown. Set before opening so "Fix Permissions…" can jump
    /// straight to the permission step even if the window is already on screen.
    var onboardingStep: OnboardingStep = .welcome
    /// A failed import/export message, surfaced as an alert in the editor window (a modal
    /// action the user initiated there, so an alert - not the menu warning line - is right).
    var importExportError: String?

    @ObservationIgnored private let defaults: UserDefaults
    /// Mirrors session state to `state.json` for external observers (AI agents and
    /// assistants, scripts) - see `SessionStateFile`.
    @ObservationIgnored private lazy var stateFile = SessionStateFile(directory: store.fileURL.deletingLastPathComponent())
    /// The in-flight typing run, so a second hotkey press can cancel (stop) it.
    @ObservationIgnored private var typingTask: Task<Void, Never>?

    private enum Keys {
        static let activeScriptID = "session.activeScriptID"
        static let didSeedSample = "onboarding.didSeedSample"
    }

    private convenience init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("UITEST")
        let store = isUITest
            ? ScriptStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("TypeCueUITest-\(UUID().uuidString)", isDirectory: true))
            : ScriptStore()
        self.init(store: store, settings: SettingsStore(), seedSample: !isUITest)
    }

    /// Designated initializer with injectable dependencies. `shared` uses the defaults;
    /// tests can wire a temporary store/settings/defaults and skip first-launch seeding.
    /// Injecting `defaults` matters: the coordinator persists the active-script id there,
    /// and tests writing to the real standard defaults would pollute the user's session.
    init(store: ScriptStore, settings: SettingsStore, seedSample: Bool, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initInterval = Signposts.launch.beginInterval("coordinator_init")
        defer { Signposts.launch.endInterval("coordinator_init", initInterval) }

        self.store = store
        self.settings = settings
        self.session = SessionController(blocksProvider: { [store] id in
            store.scripts.first { $0.id == id }?.blocks
        })
        self.engine = TypingEngine(sink: poster, resolver: KeystrokeResolver())

        // With `@Observable`, views that read a nested store/session/settings/panel
        // property through the coordinator observe that property directly - no manual
        // objectWillChange fan-out needed.

        if seedSample { seedSampleScriptIfFirstLaunch() }
        restoreActiveScript()
    }

    /// Seeds a one-time tutorial script the very first time the app runs. Gated on a
    /// persisted flag (not just "is the store empty") so it never reappears after the user
    /// deletes it.
    private func seedSampleScriptIfFirstLaunch() {
        guard !defaults.bool(forKey: Keys.didSeedSample) else { return }
        defaults.set(true, forKey: Keys.didSeedSample)
        guard store.scripts.isEmpty else { return }
        let sample = Script.sample()
        store.addScript(sample)
        setActiveScript(sample.id)
    }

    // MARK: - Lifecycle

    /// Called once at launch: registers the global hotkey and shows onboarding if the
    /// Accessibility permission is not yet granted.
    func start() {
        KeyboardShortcuts.onKeyUp(for: .typeNextBlock) { [weak self] in
            // KeyboardShortcuts delivers on the main thread; assert that isolation
            // explicitly so a future package change that violates it fails loudly instead
            // of silently racing this @MainActor coordinator's state.
            MainActor.assumeIsolated {
                self?.typeNextBlock()
            }
        }

        publishState()

        let args = ProcessInfo.processInfo.arguments
        if args.contains("UITEST_OPEN_EDITOR") {
            openEditor()
            return
        }
        if args.contains("UITEST_OPEN_ONBOARDING") {
            openOnboarding()
            return
        }
        if args.contains("UITEST_OPEN_ONBOARDING_READY") {
            openOnboarding(step: .ready)
            return
        }
        if args.contains("UITEST_OPEN_SETTINGS") {
            openSettings()
            return
        }

        permissions.refresh()
        if !permissions.isTrusted {
            openOnboarding()
        }
    }

    // MARK: - Typing flow

    /// Types the next block of the active script into the focused field. Pressing the
    /// hotkey again while a block is typing cancels (stops) it - a safety valve for retakes.
    func typeNextBlock() {
        let hotkeyInterval = Signposts.typing.beginInterval("hotkey")
        defer { Signposts.typing.endInterval("hotkey", hotkeyInterval) }

        if isTyping {
            typingTask?.cancel()
            return
        }

        clearWarning()

        guard permissions.isTrusted else {
            flashWarning("Accessibility permission needed before TypeCue can type. Grant it to continue.")
            openOnboarding(step: .permission)
            return
        }
        if PermissionManager.isSecureInputEnabled {
            flashWarning("Can't type into a password field - macOS blocks this. Click a normal text field, then press the hotkey.")
            return
        }
        guard let block = session.advance() else { return }
        // `advance()` already moved the cursor past this block; remember where it sat so a
        // cancelled run can re-arm it (rewind on cancel) instead of skipping it.
        let typedIndex = session.cursor - 1

        let segments = BlockTokenizer.tokenize(block.text)
        let pacing = currentPacing()
        let mode = settings.newlineMode

        isTyping = true
        publishState()
        typingTask = Task {
            let outcome = await engine.type(segments, pacing: pacing, newlineMode: mode)
            if outcome == .cancelled {
                session.rewind(to: typedIndex)
            }
            isTyping = false
            typingTask = nil
            publishState()
        }
    }

    /// Types an arbitrary string immediately (used by the onboarding Test Pad to verify
    /// the permission is actually functional). Typed verbatim - markers are not parsed.
    func typeTestString(_ text: String) {
        guard permissions.isTrusted, !isTyping else { return }
        let pacing = currentPacing()
        let mode = settings.newlineMode
        isTyping = true
        typingTask = Task {
            _ = await engine.type(text, pacing: pacing, newlineMode: mode)
            isTyping = false
            typingTask = nil
        }
    }

    private func currentPacing() -> PacingConfig {
        settings.pacing
    }

    // MARK: - Warnings

    /// Surfaces a blocked-press warning actively: sets the menu text and starts a brief
    /// flash (menu bar glyph + panel banner) that clears itself, so it is noticeable during
    /// recording without being intrusive.
    func flashWarning(_ message: String) {
        warning = message
        isFlashingWarning = true
        warningFlashTask?.cancel()
        warningFlashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.isFlashingWarning = false
            self?.warningFlashTask = nil
        }
    }

    private func clearWarning() {
        warning = nil
        isFlashingWarning = false
        warningFlashTask?.cancel()
        warningFlashTask = nil
    }

    // MARK: - Session helpers

    var activeScript: Script? {
        guard let id = session.activeScriptID else { return nil }
        return store.scripts.first { $0.id == id }
    }

    /// SF Symbol shown in the menu bar, reflecting the current session state (or a warning
    /// flash when a press was just blocked).
    var menuBarGlyph: MenuBarPresentation.Glyph {
        MenuBarPresentation.glyph(
            isFlashingWarning: isFlashingWarning,
            isTyping: isTyping,
            sessionState: session.state
        )
    }

    /// VoiceOver label for the menu bar item, since the SF Symbol alone would announce a
    /// raw glyph name rather than the app and its current session state.
    var menuBarAccessibilityLabel: String {
        if isFlashingWarning { return "TypeCue, action needed" }
        if isTyping { return "TypeCue, typing" }
        switch session.state {
        case .idle: return "TypeCue, idle"
        case .armed(let nextIndex, let total):
            return "TypeCue, ready to type block \(nextIndex + 1) of \(total)"
        case .complete(let total):
            return total == 0 ? "TypeCue, idle" : "TypeCue, script complete"
        }
    }

    func setActiveScript(_ id: UUID?) {
        session.setActiveScript(id)
        defaults.set(id?.uuidString, forKey: Keys.activeScriptID)
        publishState()
    }

    func resetSequence() {
        session.reset()
        clearWarning()
        publishState()
    }

    // MARK: - URL commands

    /// Handles `typecue://` URLs - the command surface for AI agents and assistants and
    /// other local tools (documented in the README's Scripting API section). Deliberately
    /// limited to session-state changes: nothing here types text or reads arbitrary files,
    /// because macOS lets any local process fire a registered URL scheme.
    func handle(url: URL) {
        guard url.scheme?.lowercased() == "typecue" else { return }
        let command = url.host?.lowercased() ?? ""
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first { $0.name == name }?.value
        }

        switch command {
        case "activate-script":
            if let idString = value("id"), let id = UUID(uuidString: idString) {
                guard store.scripts.contains(where: { $0.id == id }) else {
                    flashWarning("No script with id \(idString).")
                    return
                }
                setActiveScript(id)
            } else if let name = value("name") {
                let matches = store.scripts.filter { $0.name == name }
                switch matches.count {
                case 1:
                    setActiveScript(matches[0].id)
                case 0:
                    flashWarning("No script named \u{201C}\(name)\u{201D}.")
                default:
                    flashWarning("\(matches.count) scripts are named \u{201C}\(name)\u{201D} - rename one or activate by id.")
                }
            } else {
                flashWarning("activate-script needs a name or id parameter.")
            }
        case "reset-session":
            resetSequence()
        case "reload":
            store.reload()
            if let error = store.lastError {
                flashWarning(error)
            }
            // Re-derive the session against the (possibly changed) scripts without
            // moving the cursor: rewind(to:) clamps and recomputes.
            session.rewind(to: session.cursor)
            publishState()
        default:
            flashWarning("Unknown TypeCue command \u{201C}\(command)\u{201D}.")
        }
    }

    /// Snapshot the session for external observers. Called after every state mutation.
    private func publishState() {
        stateFile.write(state: session.state, activeScript: activeScript, isTyping: isTyping)
    }

    private func restoreActiveScript() {
        guard let raw = defaults.string(forKey: Keys.activeScriptID),
              let id = UUID(uuidString: raw),
              store.scripts.contains(where: { $0.id == id })
        else { return }
        session.setActiveScript(id)
    }

    // MARK: - Windows

    func openEditor() {
        editorTab = .scripts
        showMainWindow()
    }

    /// The unified main window hosting the Scripts editor and Settings as tabs.
    private func showMainWindow() {
        // Tall enough that the Settings tab's grouped form fits without scrolling
        // (its content is ~510pt) below the tab picker.
        windows.show(id: "editor", title: "TypeCue", size: NSSize(width: 760, height: 600), resizable: true) {
            MainWindowView().environment(self)
        }
    }

    /// Adds the built-in tutorial script on demand (also seeded automatically on first
    /// launch), makes it active, and opens the editor at it.
    func addSampleScript() {
        let sample = Script.sample()
        store.addScript(sample)
        setActiveScript(sample.id)
        openEditor()
    }

    func openSettings() {
        editorTab = .settings
        showMainWindow()
    }

    /// Opens the main window on the About tab (identity, links, acknowledgements).
    func openAbout() {
        editorTab = .about
        showMainWindow()
    }

    func openOnboarding(step: OnboardingStep = .welcome) {
        onboardingStep = step
        windows.show(id: "onboarding", title: "Welcome to TypeCue", size: NSSize(width: 560, height: 540)) {
            OnboardingView().environment(self)
        }
    }

    func closeOnboarding() {
        windows.close(id: "onboarding")
    }

    /// Sets the bundled tutorial as the active script (adding it if it is not present) and
    /// closes onboarding, so "Start the tour" from the final step drops the user right in.
    func startTour() {
        let tourName = "TypeCue tour"
        if let existing = store.scripts.first(where: { $0.name == tourName }) {
            setActiveScript(existing.id)
        } else {
            let sample = Script.sample()
            store.addScript(sample)
            setActiveScript(sample.id)
        }
        closeOnboarding()
    }

    func toggleFloatingPanel() {
        floatingPanel.toggle(coordinator: self)
    }

    // MARK: - Import / export

    func exportActiveScript() {
        guard let script = activeScript else { return }
        exportScript(script)
    }

    func exportScript(_ script: Script) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(script.name).json"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(script).write(to: url, options: [.atomic])
        } catch {
            importExportError = "Couldn't export \u{201C}\(script.name)\u{201D}: \(error.localizedDescription)"
        }
    }

    func importScript() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let imported = try JSONDecoder().decode(Script.self, from: data)
            // Assign fresh ids so an imported script never collides with an existing one.
            // Block text is already marker-migrated by TextBlock's decoder.
            let copy = Script(
                name: imported.name,
                blocks: imported.blocks.map { TextBlock(text: $0.text) }
            )
            store.addScript(copy)
        } catch {
            importExportError = "Couldn't import that file — it isn't a valid TypeCue script. (\(error.localizedDescription))"
        }
    }
}
