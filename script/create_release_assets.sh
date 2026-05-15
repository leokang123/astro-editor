#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.6}"
APP_NAME="AstroPaperEditor"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_FILE="$DIST_DIR/$APP_NAME-v$VERSION.zip"
DMG_FILE="$DIST_DIR/$APP_NAME-v$VERSION.dmg"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$ROOT_DIR/script/package_app.sh" >/dev/null

ditto --noextattr --noqtn "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME.app"

rm -f "$ZIP_FILE" "$DMG_FILE"
ditto -c -k --keepParent --noextattr --noqtn "$STAGING_DIR/$APP_NAME.app" "$ZIP_FILE"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR/$APP_NAME.app" \
  -ov \
  -format UDZO \
  "$DMG_FILE" >/dev/null

echo "$ZIP_FILE"
echo "$DMG_FILE"
