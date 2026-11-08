#!/bin/sh
# Builds a release WorkoutTimer.app into ./build
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP=build/WorkoutTimer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/WorkoutTimer" "$APP/Contents/MacOS/WorkoutTimer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
