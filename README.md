# TypeCue

A macOS menu bar app that fake-types a scripted, ordered set of text blocks into whatever
field currently has focus - one block per global-hotkey press. Built to make product demo
video recording (typing prompts into Claude, Cursor, browsers, etc.) consistent and
retake-free.

See [AGENTS.md](AGENTS.md) for the locked technical decisions and working agreement.

## How it works

1. Open "Edit Scripts" from the menu bar icon and create a named script - an ordered list
   of text blocks for one demo. New Script and Add Sample are in the editor's action bar;
   Import/Export live in its overflow menu. The window has "Scripts" and "Settings" tabs;
   "Settings" and "How TypeCue Works" in the menu open the right surface.
2. Pick it as the active script from the menu, or from the floating panel's header menu.
3. During recording, focus the target field, then press the global hotkey
   (default Ctrl+Option+X). TypeCue types the next block, human-paced.
4. Each press types the next block in order. Press the hotkey again while a block is
   typing to stop it. When the last block is typed, the sequence stops - choose "Reset"
   to start over.
5. Optionally open "Show Panel" for a floating teleprompter that shows every block with its
   state (typed / typing / next / upcoming), full text, and the current position.

Typing is real synthetic key events (indistinguishable from physical typing), with optional
natural rhythm (subtle pace variation plus pauses at spaces and punctuation). It works in
any language and keyboard layout, RTL included: characters on the active layout are typed
as real keystrokes, and anything else (emoji, other alphabets) falls back to direct Unicode
entry - switching input sources mid-session is handled automatically.

### Inline markers

Author pacing directly in a block's text (see "Formatting" in the editor):

- `[0.5]`, `[2]` - pause for that many seconds
- `[speed:20]` - type at 20 ms/character from here on; `[speed:default]` restores your set speed
- `[enter]` - press Return (submits in chat apps)

Line breaks inside a block are inserted with Shift+Return by default, so multi-line blocks
don't submit themselves in chat apps like Claude, Cursor and Slack. Switch this in Settings.

## Scripting API for AI agents

Everything TypeCue knows lives in plain files, so AI agents (Claude Code,
Cursor, or any tool with access to your machine) can author and drive your scripts:

- **Scripts**: `~/Library/Application Support/TypeCue/scripts.json` - a plain JSON array
  (`[{id, name, blocks: [{id, text}]}]`). Edit it directly, then run
  `open "typecue://reload"` so the app picks the changes up live.
- **Commands**: `typecue://activate-script?name=…` (or `?id=…`), `typecue://reset-session`,
  `typecue://reload`.
- **State**: the app mirrors its session to `state.json` next to the scripts file
  (active script, next block, typing status) so tools can observe what's happening.

The repo ships a ready-made agent skill at
[`.agents/skills/typecue`](.agents/skills/typecue/SKILL.md) - schema, guardrails, and
direction rules for pacing a script with markers. Point your agent at it (or paste
it in) and ask for things like *"turn these prompts into a well-paced TypeCue script for my
demo"*.

## Requirements

- macOS 14+ (Sonoma or later) to run
- Xcode 16.4+ (Swift 6) to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Permissions

TypeCue needs one permission: Accessibility (Privacy & Security > Accessibility), which
lets it send keystrokes to other apps. The onboarding window guides you through granting
it and includes a Test Pad to confirm it actually works. No other permission is required.

Password / secure input fields block synthetic keystrokes system-wide (a macOS rule no app
can bypass); TypeCue detects this where macOS reports it and asks you to type those
manually. Detection is best-effort - some fields don't opt into secure input, so they may
not be flagged. When a press is blocked, TypeCue flashes a warning on the menu bar icon and
in the floating panel so you notice it mid-recording, instead of only in the menu dropdown.

## Build and run

```bash
# Generate the Xcode project from project.yml (do this after pulling or editing project.yml)
xcodegen generate

# Build
xcodebuild build -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' -derivedDataPath DerivedData

# Or open in Xcode and run
open TypeCue.xcodeproj
```

The built app is a menu bar item only (no Dock icon).

## Tests

```bash
# Unit tests (engine, session, store) - run headless anywhere
xcodebuild test -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' \
  -derivedDataPath DerivedData -only-testing:TypeCueTests

# UI tests - require an interactive login/GUI session
xcodebuild test -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' \
  -derivedDataPath DerivedData -only-testing:TypeCueUITests
```

- `TypeCueTests` (Swift Testing): tokenization/pacing/jitter, layout-aware keystroke
  resolution, the typing-engine sequence including the anti-interleaving regression test,
  the session cursor state machine, and script persistence. These are the
  reliability-critical coverage and run without any permissions.
- `TypeCueUITests` (XCUITest): script/block CRUD and the onboarding surface, plus an
  end-to-end typing smoke test against the in-app Test Pad. The e2e test is skipped unless
  the test runner has Accessibility permission, and UI tests require an interactive GUI
  session (they won't run in a headless CI without a persistent, authorized runner).

## Project layout

```
Sources/TypeCue/
  App/          App entry, delegate, coordinator, window manager, floating panel controller, hotkey definition
  Engine/       TypingEngine, BlockTokenizer, Pacer, KeystrokeResolver, NewlineMode, EventSink, CGEventPoster
  Model/        Script, TextBlock
  Store/        ScriptStore (JSON in Application Support)
  Session/      SessionController (cursor state machine), PanelRowState (panel row-state logic)
  Permissions/  PermissionManager
  UI/           MenuContent, MainWindowView (Scripts + Settings tabs), EditorView, SettingsView, OnboardingView, ScriptPanelView
Sources/TypeCueTests/       Unit tests (Swift Testing)
Sources/TypeCueUITests/     UI + e2e tests (XCUITest)
```

See [docs/MANUAL_REGRESSION.md](docs/MANUAL_REGRESSION.md) for the pre-release manual check
against real target apps.

## Built with

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (global hotkey
recording) and [Sauce](https://github.com/Clipy/Sauce) (layout-aware key code
resolution), both MIT licensed - full texts in
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## License

MIT - see [LICENSE](LICENSE).
