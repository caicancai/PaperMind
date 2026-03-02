#!/usr/bin/env bash
set -euo pipefail

APP_NAME="PaperMind"
BUNDLE_ID="com.caicancai.PaperMind"
VERSION="${1:-}"
IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_BUILD=0
SKIP_NOTARIZE=0

usage() {
  cat <<EOF
Usage:
  ./scripts/release-dmg.sh <version> [options]

Options:
  --identity "<Developer ID Application: ...>"   Codesign identity (or env CODESIGN_IDENTITY)
  --notary-profile "<profile>"                   notarytool keychain profile (or env NOTARY_PROFILE)
  --skip-build                                   Skip swift release build
  --skip-notarize                                Skip notarization and stapling

Example:
  ./scripts/release-dmg.sh v0.0.1 \\
    --identity "Developer ID Application: Your Name (TEAMID)" \\
    --notary-profile "PaperMindNotary"
EOF
}

if [[ -z "$VERSION" || "$VERSION" == "--help" || "$VERSION" == "-h" ]]; then
  usage
  exit 1
fi

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity)
      IDENTITY="${2:-}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "$IDENTITY" ]]; then
  echo "Missing codesign identity. Pass --identity or set CODESIGN_IDENTITY." >&2
  exit 1
fi

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  swift build -c release
fi

BINARY_PATH="$ROOT_DIR/.build/release/$APP_NAME"
if [[ ! -x "$BINARY_PATH" ]]; then
  BINARY_PATH="$ROOT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
fi
if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Release binary not found: $BINARY_PATH" >&2
  exit 1
fi

STAGE_DIR="$ROOT_DIR/release/stage"
APP_DIR="$STAGE_DIR/$APP_NAME.app"
DMG_ROOT="$STAGE_DIR/dmg-root"
OUT_DMG="$ROOT_DIR/release/${APP_NAME}-${VERSION}.dmg"
ICON_ICNS="$ROOT_DIR/Resources/AppIcon.icns"

"$ROOT_DIR/scripts/generate-app-icon.sh" "$ROOT_DIR/assets/icon/app-icon-anime.svg" "$ROOT_DIR/Resources"

rm -rf "$STAGE_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$DMG_ROOT"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ICON_ICNS" "$APP_DIR/Contents/Resources/AppIcon.icns"

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
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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

# Sign executable first, then app bundle.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP_DIR/Contents/MacOS/$APP_NAME"
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$OUT_DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$OUT_DMG" >/dev/null

codesign --force --timestamp --sign "$IDENTITY" "$OUT_DMG"
codesign --verify --verbose=2 "$OUT_DMG"

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Missing notary profile. Pass --notary-profile or set NOTARY_PROFILE." >&2
    exit 1
  fi
  xcrun notarytool submit "$OUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_DIR"
  xcrun stapler staple "$OUT_DMG"
fi

echo "Release DMG ready: $OUT_DMG"
