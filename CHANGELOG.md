# Changelog

All notable changes to TypeCue are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org).

## [Unreleased]

## [0.1.1] - 2026-07-19

### Fixed

- Typing could stall for a moment at spaces, tabs, or line breaks when the Mac was
  under load (for example while recording the screen): those characters resolved
  their keycode through a synchronous main-thread call on every keystroke. The
  keycodes are now cached with the layout cache, so the typing path never waits on
  the main thread.
- Typing runs now hold a latency-critical activity assertion, preventing App Nap
  and timer coalescing from stretching the pauses between characters while TypeCue
  works in the background behind the target app.

## [0.1.0] - 2026-07-18

First public release.

TypeCue is a macOS menu bar app that types your script into any app - one block
per hotkey press, as real system-level keystrokes, at a human pace. Write a demo
as ordered blocks, focus the target field, and each press of the global hotkey
(default Ctrl+Option+X) types the next block: no typos, identical on every take.

### Highlights

- Scripted block typing with layout-aware synthetic keystrokes and a Unicode
  fallback for characters not on the current layout - any language, RTL included,
  with input-source switches handled mid-session.
- Inline pacing markers written directly in a block's text: `[0.5]` pauses,
  `[speed:40]` / `[speed:default]` tempo shifts, `[enter]` to submit. Line breaks
  type as Shift+Return so multi-line blocks never submit early in chat apps.
- Natural typing rhythm with slight per-character variation.
- Floating teleprompter panel showing every block and its state (typed / typing /
  next / upcoming) without ever stealing focus.
- Script editor with import/export, drag-to-reorder, and a right-click menu
  (Make Active, Duplicate, Export, Delete), plus an About tab.
- App icon with a matching menu bar mark - the caret appears exactly when a
  script is armed; the mark flashes a warning when a secure field blocks typing.
- Accessibility onboarding with a live Test Pad that proves keystrokes arrive.
- An agent surface: scripts live in plain JSON under Application Support,
  `typecue://` commands (`activate-script`, `reset-session`, `reload`) drive the
  app, a `state.json` mirror exposes the session, and a ready-made agent skill
  ships in the repo and at [typecue.app/skill.md](https://typecue.app/skill.md).
- A scripts file that fails to read is set aside as
  `scripts.json.corrupt-<timestamp>` instead of being silently replaced.

[Unreleased]: https://github.com/alexpolonsky/TypeCue/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/alexpolonsky/TypeCue/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/alexpolonsky/TypeCue/releases/tag/v0.1.0
