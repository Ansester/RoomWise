#!/bin/sh
# Fast, offline source checks. Build/test verification remains separate.
set -eu
cd "$(dirname "$0")/.."
python3 scripts/generate-xcode.py
python3 - <<'PY'
from pathlib import Path
import json
import plistlib
import re
import struct
import subprocess
import sys

root = Path.cwd()
errors = []
tracked = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"]).decode().split("\0")
for name in tracked:
    if not name:
        continue
    if name in {"config.local.properties", ".env", ".env.local"}:
        errors.append(f"Local credentials/configuration must be untracked: {name}")
        continue
    path = root / name
    if not path.is_file():
        continue
    try:
        content = path.read_text(encoding="utf-8")
    except (UnicodeError, OSError):
        continue
    # Report paths only, never matching credential material.
    if re.search(r"\b(?:sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{35,}|tvly-[A-Za-z0-9_-]{20,}|gsk_[A-Za-z0-9_-]{25,})", content):
        errors.append(f"Potential provider credential in tracked source: {name}")

project = (root / "iosApp/FitCheck.xcodeproj/project.pbxproj").read_text()
for marker in ("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon", "CURRENT_PROJECT_VERSION", "MARKETING_VERSION", "PrivacyInfo.xcprivacy in Resources"):
    if marker not in project:
        errors.append(f"Missing app release configuration: {marker}")
manifest = plistlib.loads((root / "iosApp/PrivacyInfo.xcprivacy").read_bytes())
if manifest.get("NSPrivacyTracking") is not False:
    errors.append("Unexpected tracking configuration")
if {entry["NSPrivacyCollectedDataType"] for entry in manifest.get("NSPrivacyCollectedDataTypes", [])} != {"NSPrivacyCollectedDataTypeSearchHistory", "NSPrivacyCollectedDataTypeUserID"}:
    errors.append("Privacy collection categories must match optional Groq/Tavily search/authentication")
reasons = {x["NSPrivacyAccessedAPIType"]: x["NSPrivacyAccessedAPITypeReasons"] for x in manifest["NSPrivacyAccessedAPITypes"]}
if "CA92.1" not in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []):
    errors.append("Missing app-only UserDefaults privacy reason")
iconset = root / "iosApp/Assets.xcassets/AppIcon.appiconset"
icons = json.loads((iconset / "Contents.json").read_text())
for icon in icons["images"]:
    data = (iconset / icon["filename"]).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        errors.append("App icon is not a PNG")
    else:
        width, height, depth, colour = struct.unpack(">IIBB", data[16:26])
        if (width, height, depth, colour) != (1024, 1024, 8, 2):
            errors.append("App icon must be opaque, RGB, 1024 x 1024")
if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)
print("Release source checks passed: app resources, privacy, versioning and tracked credentials.")
print("This checks current tracked files; it does not purge credentials from Git history or revoke old keys.")
PY
