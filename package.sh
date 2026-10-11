#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
APP="build/PingTogether.app"
"$APP/Contents/MacOS/PingTogether" --self-test
codesign --verify --deep "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
PACKAGE_NAME="PingTogether-$VERSION-macOS"
PACKAGE_STAGE=$(mktemp -d /tmp/pingtogether-package.XXXXXX)
trap 'rm -rf "$PACKAGE_STAGE"' EXIT
mkdir -p "$PACKAGE_STAGE/content" dist
ditto "$APP" "$PACKAGE_STAGE/content/PingTogether.app"
cp 使用说明.txt "$PACKAGE_STAGE/content/使用说明.txt"
cp 素材来源.txt "$PACKAGE_STAGE/content/素材来源.txt"
ln -s /Applications "$PACKAGE_STAGE/content/Applications"
xattr -cr "$PACKAGE_STAGE/content"
codesign --verify --deep --strict "$PACKAGE_STAGE/content/PingTogether.app"
hdiutil create -quiet -volname "PingTogether $VERSION" \
  -srcfolder "$PACKAGE_STAGE/content" -format UDZO -ov "$PACKAGE_STAGE/$PACKAGE_NAME.dmg"
hdiutil verify "$PACKAGE_STAGE/$PACKAGE_NAME.dmg"
cp "$PACKAGE_STAGE/$PACKAGE_NAME.dmg" "dist/$PACKAGE_NAME.dmg"
(cd dist && shasum -a 256 "$PACKAGE_NAME.dmg" > "$PACKAGE_NAME.sha256")
echo "Ready: $PWD/dist/$PACKAGE_NAME.dmg"
