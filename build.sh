#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
STAGING=$(mktemp -d /tmp/pingtogether-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/PingTogether.app"
mkdir -p "$APP/Contents/MacOS"
clang -arch arm64 -arch x86_64 -mmacosx-version-min=12.0 \
  -fobjc-arc -Wall -Wextra -Werror -Wno-deprecated-declarations \
  -framework Cocoa -framework Carbon -framework AVFoundation -framework CoreAudio \
  src/main.m -o "$APP/Contents/MacOS/PingTogether"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
ditto assets "$APP/Contents/Resources/assets"
# Package the existing question-mark artwork as a native macOS icon.
ICONSET="$STAGING/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" assets/textures/enemy_missing.png \
    --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" assets/textures/enemy_missing.png \
    --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"
codesign --force --sign - "$APP"
mkdir -p build
ditto "$APP" build/PingTogether.app
echo "Built: $PWD/build/PingTogether.app"
