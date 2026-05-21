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
VOLUME_PATH=""

cleanup() {
  if [[ -n "$VOLUME_PATH" ]]; then
    hdiutil detach "$VOLUME_PATH" -quiet 2>/dev/null || true
  fi
  rm -rf "$STAGING_DIR"
  rm -f "$RW_DMG_FILE"
}
trap cleanup EXIT

"$ROOT_DIR/script/package_app.sh" >/dev/null

BACKGROUND_DIR="$STAGING_DIR/.background"
BACKGROUND_FILE="$BACKGROUND_DIR/background.png"
mkdir -p "$BACKGROUND_DIR"
swift - "$BACKGROUND_FILE" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = NSSize(width: 600, height: 360)
let image = NSImage(size: size)

image.lockFocus()
NSColor.windowBackgroundColor.setFill()
NSRect(origin: .zero, size: size).fill()

let arrowColor = NSColor.secondaryLabelColor.withAlphaComponent(0.45)
arrowColor.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.move(to: NSPoint(x: 260, y: 190))
arrow.line(to: NSPoint(x: 340, y: 190))
arrow.move(to: NSPoint(x: 318, y: 212))
arrow.line(to: NSPoint(x: 340, y: 190))
arrow.line(to: NSPoint(x: 318, y: 168))
arrow.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.75),
    .paragraphStyle: paragraph
]
"Drag to Applications".draw(
    in: NSRect(x: 0, y: 62, width: size.width, height: 30),
    withAttributes: attributes
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to create DMG background image")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

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

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG_FILE" \
  -readwrite \
  -noverify \
  -noautoopen)"
VOLUME_PATH="$(printf "%s\n" "$ATTACH_OUTPUT" | awk '/\/Volumes\// { print substr($0, index($0, "/Volumes/")); exit }')"

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$VOLUME_PATH" as alias
  set backgroundImage to POSIX file "$VOLUME_PATH/.background/background.png" as alias
  open dmgFolder
  delay 0.5
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set pathbar visible of container window of dmgFolder to false
  set sidebar width of container window of dmgFolder to 0
  set bounds of container window of dmgFolder to {360, 240, 960, 600}
  set viewOptions to icon view options of container window of dmgFolder
  set arrangement of viewOptions to not arranged
  set background picture of viewOptions to backgroundImage
  set icon size of viewOptions to 112
  set arrangement of viewOptions to not arranged
  set position of item "$APP_NAME.app" of container window of dmgFolder to {185, 170}
  set position of item "Applications" of container window of dmgFolder to {415, 170}
  update item "$APP_NAME.app" of container window of dmgFolder
  update item "Applications" of container window of dmgFolder
  delay 0.2
  set position of item "$APP_NAME.app" of container window of dmgFolder to {185, 170}
  set position of item "Applications" of container window of dmgFolder to {415, 170}
  delay 2
  close container window of dmgFolder
end tell
APPLESCRIPT

sync

hdiutil detach "$VOLUME_PATH" -quiet
VOLUME_PATH=""
hdiutil convert "$RW_DMG_FILE" \
  -format UDZO \
  -o "$DMG_FILE" >/dev/null

echo "$ZIP_FILE"
echo "$DMG_FILE"
