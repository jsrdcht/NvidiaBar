#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="/Applications/NvidiaBar.app"
BUNDLE_ID="${APP_BUNDLE_ID:-io.github.nvidiabar.app}"
APP_PATH="$(APP_BUNDLE_ID="$BUNDLE_ID" "$ROOT_DIR/scripts/build_app.sh")"
SERVER_CONFIGS_JSON='[]'
SERVER_CONFIGS_HEX="$(printf '%s' "$SERVER_CONFIGS_JSON" | xxd -p -c 999999 | tr -d '\n')"

rm -rf "$TARGET_DIR"
cp -R "$APP_PATH" "$TARGET_DIR"
/usr/bin/codesign --force --deep --sign - "$TARGET_DIR" >/dev/null
/usr/bin/defaults write "$BUNDLE_ID" "NvidiaBar.serverConfigs" -data "$SERVER_CONFIGS_HEX"
/usr/bin/defaults write "$BUNDLE_ID" "NvidiaBar.appTheme" -string "light"

echo "$TARGET_DIR"
