#!/bin/sh
# Build a Release archive for inspection/Organizer. Never uploads or publishes.
# Usage: sh scripts/archive-ios.sh [--unsigned] [archive-path]
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
unsigned=false
if [ "${1:-}" = "--unsigned" ]; then
  unsigned=true
  shift
fi
if [ "$#" -gt 1 ]; then
  echo "Usage: sh scripts/archive-ios.sh [--unsigned] [archive-path]" >&2
  exit 2
fi
archive_path=${1:-"$PWD/build/release/RoomWise.xcarchive"}
case "$archive_path" in
  /*) ;;
  *) archive_path="$PWD/$archive_path" ;;
esac
if [ -e "$archive_path" ]; then
  echo "Archive already exists. Supply a new archive path to preserve it." >&2
  exit 1
fi
sh scripts/release-check.sh
if [ "$unsigned" = true ]; then
  xcodebuild -project iosApp/FitCheck.xcodeproj -scheme FitCheck \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" CODE_SIGNING_ALLOWED=NO archive
else
  xcodebuild -project iosApp/FitCheck.xcodeproj -scheme FitCheck \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" archive
fi
python3 - "$archive_path" <<'PY'
from pathlib import Path
import plistlib
import sys

archive = Path(sys.argv[1])
apps = list((archive / "Products/Applications").glob("*.app"))
if len(apps) != 1:
    sys.exit("Archive must contain exactly one app")
app = apps[0]
info = plistlib.loads((app / "Info.plist").read_bytes())
for key in ("CFBundleShortVersionString", "CFBundleVersion", "CFBundleIcons"):
    if not info.get(key):
        sys.exit(f"Archived app is missing {key}")
if not (app / "PrivacyInfo.xcprivacy").is_file():
    sys.exit("Archived app is missing its privacy manifest")
source = Path("iosApp/Generated/LocalDebugSecrets.generated.swift").read_text()
if 'static let openAIKey: String? = nil' not in source or 'static let tavilyKey: String? = nil' not in source:
    sys.exit("Release credential stub is not nil-only")
print(f"Verified Release archive: {archive}")
print(f"Version {info['CFBundleShortVersionString']} ({info['CFBundleVersion']})")
PY
if [ "$unsigned" = true ]; then
  echo "Unsigned archive prepared for local verification. Signing is required before App Store upload."
else
  echo "Signed archive prepared. Open it in Xcode Organizer for validation and upload when ready."
fi
