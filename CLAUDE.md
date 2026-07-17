# TypeCue - agent notes

Read `AGENTS.md` first (working agreement, build commands, testing rules). This file
only adds agent-workflow practice. The `typecue` skill (`.agents/skills/typecue`)
covers authoring and driving the app's scripts.

## Skills

- `verify` - build/test/launch/screenshot loop for confirming changes visually.
- `changelog` - when and how to update CHANGELOG.md (do it in the same change).
- `release` - full release checklist; release dmg builds require Xcode 26.

## Commits

- Plain descriptive messages: what changed and why it matters, imperative-ish title,
  body only when the why isn't obvious. No conventional-commits prefixes.
- One concern per commit. Doc sync (README, checklists) belongs in the same commit
  as the change it documents.
- Never push `backup-*` branches.

## Environment gotchas

- Building with Xcode 16.4+ works (deployment target is macOS 14.0); the Tahoe
  appearance comes from building with Xcode 26, so release builds use that. Some
  SourceKit single-file diagnostics ("No such module", "Cannot find type") are noise -
  trust `xcodebuild`.
- Tests that type Latin text through the real resolver skip under a non-Latin active
  keyboard layout (see `LayoutGate` in TypeCueTests).
- After editing `project.yml` or adding/removing files: `xcodegen generate`.
