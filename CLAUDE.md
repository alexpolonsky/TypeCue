# TypeCue - agent notes

Read `AGENTS.md` first (working agreement, build commands, testing rules) and
`PROJECT_BRIEF.md` before product/architecture decisions. This file only adds
Claude-Code-specific practice.

## Skills

- `verify` - build/test/launch/screenshot loop for confirming changes visually.
- `changelog` - when and how to update CHANGELOG.md (do it in the same change).
- `release` - full release checklist; dmg builds happen on the Xcode 26 machine only.

## Commits

- Plain descriptive messages: what changed and why it matters, imperative-ish title,
  body only when the why isn't obvious. No conventional-commits prefixes.
- One concern per commit. Doc sync (PROJECT_BRIEF/README) belongs in the same commit
  as the change it documents.
- Never push `backup-*` branches (pre-squash history).

## Environment gotchas

- This dev machine runs macOS Sequoia + Xcode 16.4; deployment target is 14.0. Some
  SourceKit single-file diagnostics ("No such module", "Cannot find type") are noise -
  trust `xcodebuild`.
- `KeystrokeResolverTests` fail under a non-Latin active keyboard layout (they resolve
  against the live layout). Switch to English/ABC before blaming a change.
- After editing `project.yml` or adding/removing files: `xcodegen generate`.
