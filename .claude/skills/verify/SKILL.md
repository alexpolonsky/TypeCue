---
name: verify
description: Build, test, and visually verify TypeCue changes end-to-end - launch specific app surfaces via UITEST launch args and capture window screenshots to confirm UI changes actually render correctly.
---

# Verifying TypeCue changes

Run from the repo root. Regenerate the project first if `project.yml` changed or files
were added/removed: `xcodegen generate`.

## 1. Build + unit tests

```bash
xcodebuild build -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' -derivedDataPath DerivedData
xcodebuild test -project TypeCue.xcodeproj -scheme TypeCue -destination 'platform=macOS' -derivedDataPath DerivedData -only-testing:TypeCueTests
```

Gotcha: `KeystrokeResolverTests` resolve against the CURRENT system keyboard layout.
If a non-Latin input source (e.g. Hebrew) is active, one test fails spuriously.
Check with the snippet in step 3 style (`TISCopyCurrentKeyboardInputSource`) or just
note the layout before blaming a change.

## 2. Launch a specific surface

The app opens surfaces directly via launch arguments (see `AppCoordinator.start()`):

```bash
killall TypeCue 2>/dev/null; sleep 1
open DerivedData/Build/Products/Debug/TypeCue.app --args UITEST_OPEN_EDITOR
# also: UITEST_OPEN_SETTINGS, UITEST_OPEN_ONBOARDING, UITEST_OPEN_ONBOARDING_READY
```

Plain `open ...TypeCue.app` (no args) launches normal behavior. Adding the `UITEST`
arg (alone) additionally isolates the ScriptStore to a temp directory.

## 3. Screenshot the app window

NEVER capture the full screen (it grabs the user's other windows). Capture the
TypeCue window by ID:

```bash
W=$(swift - <<'EOF' 2>/dev/null
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerName"] as? String) == "TypeCue" {
    let b = w["kCGWindowBounds"] as! [String: Any]
    if (b["Height"] as! Double) > 100 { print(w["kCGWindowNumber"]!); break }
}
EOF
)
screencapture -x -o -l "$W" /path/to/shot.png
```

Requires Screen Recording permission for the terminal (already granted on this
machine). To crop (e.g. to compare footer strips), use CoreGraphics via a `swift -`
heredoc - `sips` crop flags are unreliable.

## 4. Full checklist before calling a change done

- Build succeeds, TypeCueTests green (mind the layout gotcha).
- The affected surface screenshotted and visually correct (light AND dark if the
  change is appearance-sensitive).
- Typing-path changes: also run the manual smoke against a real target app
  (docs/MANUAL_REGRESSION.md has the full pre-release list).
- Docs synced per AGENTS.md (PROJECT_BRIEF.md stays current in the same change).
