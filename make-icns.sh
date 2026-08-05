#!/bin/bash
# Run this script on macOS to convert the iconset into an .icns file.
# Run this script on macOS before building the app.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONSET="$SCRIPT_DIR/assets/icon.iconset"
ICNS="$SCRIPT_DIR/assets/icon.icns"

echo "Converting iconset to .icns ..."
iconutil -c icns "$ICONSET" -o "$ICNS"

if [ -f "$ICNS" ]; then
  echo "icon.icns created at $ICNS"
  echo "Now run: ./scripts/build-macos.sh"
else
  echo "Failed. Make sure you're on macOS with Xcode tools installed."
fi
