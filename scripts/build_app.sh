#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="NvidiaBar"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-io.github.nvidiabar.app}"

mkdir -p "$BUILD_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

SOURCE_FILES=("${(@f)$(find "$ROOT_DIR/Sources/NvidiaBar" -name '*.swift' | sort)}")

swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  "${SOURCE_FILES[@]}" \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NvidiaBar</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NvidiaBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/$APP_NAME"
/usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
