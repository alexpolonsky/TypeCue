<p align="center">
  <img src="site/icon-180.png" width="96" alt="TypeCue icon">
</p>

<h1 align="center">TypeCue</h1>

<p align="center"><b>Press a key. It types the line.</b><br>
A macOS menu bar app that types your script into any app - one block per hotkey press,
as real keystrokes, at a human pace.</p>

<p align="center">
  <a href="https://typecue.app">typecue.app</a> ·
  <a href="https://github.com/alexpolonsky/TypeCue/releases/latest">Download</a> ·
  <a href="#scripting-api-for-ai-agents">For AI agents</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/github/license/alexpolonsky/TypeCue" alt="MIT">
</p>

---

Typing on screen while people watch - demo videos, tutorials, webinars, live
presentations - goes wrong in exactly one way: the typing. TypeCue plays a prepared
script instead. Write your demo as ordered blocks; during the take, each press of a
global hotkey (default Ctrl+Option+X) types the next block into whatever field has
focus. Real system-level keystrokes, human pacing, no typos, identical on every take.

https://github.com/user-attachments/assets/110686e2-2e6b-41c2-9781-e51b36c8563a

## Install

**Download**: grab [the latest release](https://github.com/alexpolonsky/TypeCue/releases/latest),
drag TypeCue to Applications, and grant the one permission it asks for (Accessibility -
the macOS API for sending keystrokes; there is a Test Pad in onboarding to verify it).

**Homebrew**:

```bash
brew install --cask alexpolonsky/tap/typecue
```

**Build from source**:

```bash
git clone https://github.com/alexpolonsky/TypeCue && cd TypeCue
xcodegen generate    # brew install xcodegen if needed
xcodebuild build -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' -derivedDataPath DerivedData
```

Requires macOS 14+ to run, Xcode 16.4+ to build.

## How it works

1. Open **Edit Scripts** from the menu bar icon and write a script - an ordered list of
   text blocks, one per beat of your demo.
2. Pick it as the active script (menu bar, floating panel, or `typecue://` command).
3. Focus the target field and press the hotkey. Each press types the next block; press
   mid-type to stop; the menu bar caret shows when a script is armed.
4. Optional: **Show Panel** opens a floating teleprompter with every block and its state
   (typed / typing / next / upcoming) that never steals focus.

### Pacing markers

Direct the typing inline, inside a block's text:

| Marker | Effect |
|---|---|
| `[0.5]`, `[2]` | pause that many seconds |
| `[speed:40]` | 40 ms/character from here on; `[speed:default]` restores your set speed |
| `[enter]` | press Return (submits in chat apps) |

Line breaks inside a block are typed as Shift+Return by default so multi-line blocks
never submit early in chat apps. Unrecognized brackets (`array[0]`) are typed literally.

Typing works in any language and keyboard layout, RTL included: characters on the active
layout go out as real keystrokes, everything else arrives by direct Unicode entry, and
switching input sources mid-session is handled automatically.

## Scripting API for AI agents

Everything TypeCue knows lives in plain files, so AI agents (Claude Code, Cursor, or any
tool with access to your machine) can author and drive your scripts:

- **Scripts**: `~/Library/Application Support/TypeCue/scripts.json` - a plain JSON array
  (`[{id, name, blocks: [{id, text}]}]`). Edit it directly, then run
  `open "typecue://reload"` so the app picks the changes up live.
- **Commands**: `typecue://activate-script?name=…` (or `?id=…`), `typecue://reset-session`,
  `typecue://reload`.
- **State**: the app mirrors its session to `state.json` next to the scripts file
  (active script, next block, typing status) so tools can observe what's happening.

The repo ships a ready-made agent skill at
[`.agents/skills/typecue`](.agents/skills/typecue/SKILL.md) (served raw at
[typecue.app/skill.md](https://typecue.app/skill.md)) - the schema, guardrails, and
screencast-direction rules for pacing a script. Give your agent one line:

```
Read https://typecue.app/skill.md and set up my TypeCue scripts.
```

Any agent that can fetch a URL, edit files, and run shell commands qualifies: Claude
Code and Cursor are tested; Claude with computer access and Codex work the same way.
Chat-only assistants can still author the JSON for you to paste - they just can't drive
the app.

## Permissions and limits

Accessibility is the only permission - no account, no network calls, no analytics.
Password and secure fields block synthetic typing system-wide (a macOS rule for every
app); TypeCue detects this and flashes a warning on the menu bar icon and floating panel
instead of silently consuming your block.

## Tests

```bash
# Unit tests (engine, session, store) - headless
xcodebuild test -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' \
  -derivedDataPath DerivedData -only-testing:TypeCueTests

# UI tests - need an interactive GUI session
xcodebuild test -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' \
  -derivedDataPath DerivedData -only-testing:TypeCueUITests
```

The unit suite covers tokenization and pacing, layout-aware keystroke resolution, the
typing sequence (including the anti-interleaving regression), the session state machine,
and persistence. Tests that type Latin text through the real resolver skip under a
non-Latin active keyboard layout. See
[docs/MANUAL_REGRESSION.md](docs/MANUAL_REGRESSION.md) for the pre-release human pass
against real target apps.

## Project layout

```
Sources/TypeCue/
  App/          App entry, delegate, coordinator, windows, floating panel, hotkey
  Engine/       TypingEngine, BlockTokenizer, Pacer, KeystrokeResolver, CGEventPoster
  Model/        Script, TextBlock
  Store/        ScriptStore (plain JSON in Application Support)
  Session/      SessionController (cursor state machine), state.json mirror
  Permissions/  PermissionManager
  UI/           Menu, main window (Scripts / Settings / About), editor, onboarding, panel
```

See [AGENTS.md](AGENTS.md) for locked technical decisions and the working agreement.

## Built with

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and
[Sauce](https://github.com/Clipy/Sauce), both MIT licensed - full texts in
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## License

MIT - see [LICENSE](LICENSE).
