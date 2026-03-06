#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$("$ROOT_DIR/scripts/build_app.sh")"
TARGET_DIR="/Applications/NvidiaBar.app"

rm -rf "$TARGET_DIR"
cp -R "$APP_PATH" "$TARGET_DIR"
/usr/bin/codesign --force --deep --sign - "$TARGET_DIR" >/dev/null

echo "$TARGET_DIR"
