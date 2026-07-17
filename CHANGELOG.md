# Changelog

All notable changes to TypeCue are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org).

## [Unreleased]

Initial development toward 0.1.0, the first public release: menu bar app with
scripted block typing (layout-aware synthetic keystrokes, Unicode fallback for
characters not on the current layout), inline pacing markers, natural typing
rhythm, floating teleprompter panel, script editor with import/export, and
Accessibility onboarding with a live Test Pad.

### Added

- An About tab, drag-to-reorder for scripts, and a right-click menu on scripts
  (Make Active, Duplicate, Export, Delete).
- App icon and a matching menu bar mark - the caret appears in the menu bar exactly
  when a script is armed.
- `typecue://` commands (`activate-script`, `reset-session`, `reload`) so AI agents,
  assistants, and scripts can drive the app, plus a `state.json` session mirror they
  can observe.
- About TypeCue in the menu, with project links and open-source acknowledgements.
- A ready-made agent skill (`.agents/skills/typecue`) for authoring and pacing scripts.

### Changed

- Default hotkey is now Ctrl+Option+X.
- Onboarding is shorter and clearer; the tour script now mixes pauses, speed
  changes, and sends the way a real demo script does.

### Fixed

- A scripts file that fails to read is set aside as `scripts.json.corrupt-<timestamp>`
  instead of being silently replaced on the next save.
