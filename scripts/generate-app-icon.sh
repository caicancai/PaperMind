#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_SVG="${1:-$ROOT_DIR/assets/icon/app-icon-anime.svg}"
OUT_DIR="${2:-$ROOT_DIR/Resources}"
ICONSET_DIR="/tmp/PaperMind.iconset"
BASE_PNG="/tmp/PaperMind-icon-1024.png"

if [[ ! -f "$SRC_SVG" ]]; then
  echo "Icon source not found: $SRC_SVG" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

qlmanage -t -s 1024 -o /tmp "$SRC_SVG" >/dev/null 2>&1
cp "/tmp/$(basename "$SRC_SVG").png" "$BASE_PNG"

make_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET_DIR" -o "$OUT_DIR/AppIcon.icns"
echo "Generated icon: $OUT_DIR/AppIcon.icns"
