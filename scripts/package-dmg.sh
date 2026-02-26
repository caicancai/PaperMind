#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PaperMind"
BUILD_CONFIG="release"
VERSION=""
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      BUILD_CONFIG="debug"
      shift
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "$VERSION" ]]; then
  VERSION="$(git describe --tags --always --dirty 2>/dev/null || date +%Y%m%d)"
fi

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  if ! swift build -c "$BUILD_CONFIG"; then
    if [[ "$BUILD_CONFIG" == "release" ]]; then
      echo "Release build failed, fallback to debug binary..." >&2
      BUILD_CONFIG="debug"
      swift build -c debug || true
    fi
  fi
fi

BINARY_PATH="$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME"
if [[ ! -x "$BINARY_PATH" ]]; then
  BINARY_PATH="$ROOT_DIR/.build/arm64-apple-macosx/$BUILD_CONFIG/$APP_NAME"
fi
if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Binary not found: $APP_NAME ($BUILD_CONFIG)" >&2
  exit 1
fi

STAGE_DIR="$ROOT_DIR/release/stage"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
DMG_ROOT="$STAGE_DIR/dmg-root"
OUT_DMG="$ROOT_DIR/release/${APP_NAME}-${VERSION}.dmg"

rm -rf "$STAGE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DMG_ROOT"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.caicancai.$APP_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$OUT_DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$OUT_DMG" >/dev/null

echo "DMG created: $OUT_DMG"
