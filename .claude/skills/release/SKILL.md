---
name: release
description: TypeCue release process - version bump, changelog cut, manual regression, notarized dmg build on the Xcode 26 machine, GitHub release and tag.
---

# Releasing TypeCue

Two-machine rule: the SOURCE can be developed and published from any machine, but the
DISTRIBUTED build (dmg) must be produced on the machine with Xcode 26 / macOS Tahoe -
the Tahoe appearance is granted by the BUILD SDK, not the deployment target. Building
the release dmg with Xcode 16.x would ship the legacy look to Tahoe users.

## Checklist

1. **Green state**: `xcodegen generate`, build, `TypeCueTests` pass (use a Latin
   keyboard layout - see the verify skill's gotcha).
2. **Manual regression**: run `docs/MANUAL_REGRESSION.md` against real target apps.
3. **Version**: bump `MARKETING_VERSION` (and `CURRENT_PROJECT_VERSION`) in
   `project.yml`; regenerate.
4. **Changelog**: cut `[Unreleased]` into `[X.Y.Z] - date` (see changelog skill).
5. **Docs**: README and AGENTS.md reflect any behavior changes.
6. **Build the dmg (Xcode 26 machine)**: Release config archive, sign with the
   Developer ID Application certificate (paid account, team TK8UD5BXJM), then
   notarize with `xcrun notarytool submit --wait` and `xcrun stapler staple`.
   Hardened runtime is already Release-only in `project.yml`.
7. **Tag + GitHub release**: commit, `git tag vX.Y.Z`, push with tags, then
   `gh release create vX.Y.Z TypeCue-X.Y.Z.dmg --title "TypeCue X.Y.Z" --notes-file <(changelog section)`.
8. **Website**: update the download link/version on typecue.app if it pins a version.

## Notes

- Never commit signing identities; `DEVELOPMENT_TEAM` in project.yml is the dev
  (Apple Development) team and is fine to publish - contributors substitute their own.
- The unsigned/dev build path stays documented in README for people building from
  source; Gatekeeper caveats only apply to the distributed binary, which notarization
  solves.
