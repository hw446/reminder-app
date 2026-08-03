#!/bin/bash
# 在 Mac 上运行此脚本，将 iconset 转换为 .icns 文件
# Run this script on your Mac before npm run build

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICONSET="$SCRIPT_DIR/assets/icon.iconset"
ICNS="$SCRIPT_DIR/assets/icon.icns"

echo "Converting iconset to .icns ..."
iconutil -c icns "$ICONSET" -o "$ICNS"

if [ -f "$ICNS" ]; then
  echo "✅ icon.icns created at $ICNS"
  echo "Now run: npm run build"
else
  echo "❌ Failed. Make sure you're on macOS with Xcode tools installed."
fi
