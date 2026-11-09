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

# App icon: Resources/icon-1024.png (regenerate with: swift scripts/make-icon.swift Resources/icon-1024.png)
mkdir -p "$APP/Contents/Resources"
ICONSET=build/AppIcon.iconset
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
