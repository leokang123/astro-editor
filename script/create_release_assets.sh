#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.4.0}"
APP_NAME="AstroPaperEditor"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_FILE="$DIST_DIR/$APP_NAME-v$VERSION.zip"
DMG_FILE="$DIST_DIR/$APP_NAME-v$VERSION.dmg"
RW_DMG_FILE="$DIST_DIR/$APP_NAME-v$VERSION-rw.dmg"
STAGING_DIR="$(mktemp -d)"
MOUNT_DIR="$(mktemp -d)"

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rm -rf "$STAGING_DIR"
  rm -rf "$MOUNT_DIR"
  rm -f "$RW_DMG_FILE"
}
trap cleanup EXIT

"$ROOT_DIR/script/package_app.sh" >/dev/null

ditto --noextattr --noqtn "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"

rm -f "$ZIP_FILE" "$DMG_FILE"
ditto -c -k --keepParent --noextattr --noqtn "$STAGING_DIR/$APP_NAME.app" "$ZIP_FILE"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  "$RW_DMG_FILE" >/dev/null

hdiutil attach "$RW_DMG_FILE" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  open dmgFolder
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set bounds of container window of dmgFolder to {260, 180, 820, 500}
  set viewOptions to icon view options of container window of dmgFolder
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set position of item "$APP_NAME.app" of dmgFolder to {155, 155}
  set position of item "Applications" of dmgFolder to {405, 155}
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_DIR" -quiet
hdiutil convert "$RW_DMG_FILE" \
  -format UDZO \
  -o "$DMG_FILE" >/dev/null

echo "$ZIP_FILE"
echo "$DMG_FILE"
