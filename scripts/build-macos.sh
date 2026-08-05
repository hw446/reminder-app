#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_PATH="$OUTPUT_DIR/Reminder Assistant.app"
DMG_PATH="$OUTPUT_DIR/Reminder-Assistant-1.1.0.dmg"
STAGING_DIR="$(mktemp -d)"

trap 'rm -rf "$STAGING_DIR"' EXIT

swift build --package-path "$PROJECT_DIR" -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build --package-path "$PROJECT_DIR" -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP_PATH" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/ReminderAssistant" "$APP_PATH/Contents/MacOS/ReminderAssistant"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$PROJECT_DIR/assets/icon.icns" "$APP_PATH/Contents/Resources/icon.icns"
codesign --force --deep --sign - "$APP_PATH"

ditto "$APP_PATH" "$STAGING_DIR/Reminder Assistant.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "Reminder Assistant" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

echo "$APP_PATH"
echo "$DMG_PATH"
