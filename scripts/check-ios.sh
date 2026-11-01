#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "==> 1. Building unsigned FitCheck application target for iOS device..."
xcodebuild -quiet -project iosApp/FitCheck.xcodeproj -target FitCheck -sdk iphoneos -configuration Debug CONFIGURATION_BUILD_DIR="$PWD/iosApp/build/device" CODE_SIGNING_ALLOWED=NO build

echo "==> 2. Locating iOS Simulator for XCTest suite..."
SIM_ID=$(xcrun simctl list devices available | grep -E 'iPhone.*Booted' | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true)
if [ -z "$SIM_ID" ]; then
    SIM_ID=$(xcrun simctl list devices available | grep -E 'iPhone' | head -n 1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true)
fi

if [ -z "$SIM_ID" ]; then
    echo "ERROR: No available iPhone simulator found to run tests."
    exit 1
fi

echo "==> 3. Running FitCheckTests on simulator ($SIM_ID)..."
xcodebuild test -project iosApp/FitCheck.xcodeproj -scheme FitCheckTests -destination "platform=iOS Simulator,id=$SIM_ID"
