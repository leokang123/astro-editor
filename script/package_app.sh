#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AstroPaperEditor"
BUNDLE_ID="dev.jeonghoon.AstroPaperEditor"
APP_VERSION="0.5.0"
BUILD_NUMBER="50"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
SWIFT_BUILD_OPTIONS=()

if [[ -n "${SWIFT_BUILD_FLAGS:-}" ]]; then
  read -r -a SWIFT_BUILD_OPTIONS <<< "$SWIFT_BUILD_FLAGS"
fi

cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/package.json" ]]; then
  if [[ ! -d "$ROOT_DIR/node_modules" ]]; then
    echo "node_modules is missing. Run npm ci before packaging." >&2
    exit 1
  fi
  npm run build:codemirror
fi

swift build -c release "${SWIFT_BUILD_OPTIONS[@]}"
BUILD_BINARY="$(swift build -c release "${SWIFT_BUILD_OPTIONS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
fi
for resource in "$ROOT_DIR"/Resources/AstroPaperStarter.*; do
  [[ -f "$resource" ]] && cp "$resource" "$APP_RESOURCES/"
done
if [[ -d "$ROOT_DIR/Resources/CodeMirror" ]]; then
  cp -R "$ROOT_DIR/Resources/CodeMirror" "$APP_RESOURCES/"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"
xattr -cr "$APP_BUNDLE"

echo "$APP_BUNDLE"
