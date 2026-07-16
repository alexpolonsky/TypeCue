#!/bin/bash
# Opens TypeCue after a successful `xcodebuild ... build` for this project.
# Hook event: afterShellExecution (see .cursor/hooks.json).
#
# Note on the payload: Cursor's afterShellExecution input has NO exit-code field. It
# provides `command` and `output`, so success is inferred from the command shape plus the
# absence of "BUILD FAILED" in the output. Fails open (exit 0) so builds are never blocked.

set -euo pipefail

input=$(cat)

python3 - "$input" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

raw = sys.argv[1] if len(sys.argv) > 1 else ""

try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    sys.exit(0)

command = str(data.get("command") or "")
output = str(data.get("output") or "")
cwd = data.get("cwd") or os.getcwd()

# React only to a build (not test) command for this project.
if "xcodebuild" not in command:
    sys.exit(0)
if re.search(r"\bxcodebuild\s+test\b", command):
    sys.exit(0)
if not re.search(r"\bxcodebuild\b.*\bbuild\b", command):
    sys.exit(0)
if "TypeCue" not in command:
    sys.exit(0)

# No exit code in the payload; infer failure from the output when the marker is present.
if "BUILD FAILED" in output:
    sys.exit(0)

root = Path(cwd)

derived_match = re.search(r"-derivedDataPath\s+(\S+)", command)
derived = Path(derived_match.group(1)) if derived_match else Path("DerivedData")
if not derived.is_absolute():
    derived = root / derived

config = "Release" if re.search(r"-configuration\s+Release\b", command) else "Debug"
app_path = derived / "Build" / "Products" / config / "TypeCue.app"

if not app_path.is_dir():
    sys.exit(0)

# Replace any running instance so the freshly built binary is what launches (also matters
# with ad-hoc signing, where the CDHash changes every build).
subprocess.run(["/usr/bin/killall", "TypeCue"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["/usr/bin/open", str(app_path)], check=False)
PY
