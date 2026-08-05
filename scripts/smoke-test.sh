#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/Reminder Assistant.app"

"$APP_PATH/Contents/MacOS/ReminderAssistant" --smoke-test
