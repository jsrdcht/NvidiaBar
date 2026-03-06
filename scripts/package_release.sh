#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
VERSION="${1:-${APP_VERSION:-0.1.0}}"
BUILD_NUMBER="${APP_BUILD:-1}"
ARCHIVE_NAME="NvidiaBar-${VERSION}.zip"

mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$ARCHIVE_NAME"

APP_VERSION="$VERSION" APP_BUILD="$BUILD_NUMBER" zsh "$ROOT_DIR/scripts/build_app.sh" >/tmp/nvidiabar_build_path.txt
APP_PATH="$(tail -n 1 /tmp/nvidiabar_build_path.txt)"

ditto -c -k --keepParent "$APP_PATH" "$DIST_DIR/$ARCHIVE_NAME"

echo "$DIST_DIR/$ARCHIVE_NAME"
