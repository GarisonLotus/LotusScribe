#!/bin/bash
# scripts/make-icns.sh — assemble AppIcon.icns from the rendered AppIcon set.
# The .appiconset PNGs (written by `make appicon`'s --render-app-icon step) are
# the single source of truth; this maps them to the iconutil naming and emits a
# complete .icns (16…512@2x) tracked in Sources/ and bundled into the app.
set -euo pipefail

SRC="Sources/LotusScribe/Assets.xcassets/AppIcon.appiconset"
OUT="Sources/LotusScribe/AppIcon.icns"
IS="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$IS"

# iconset name  <-  source pixel PNG
cp "$SRC/icon_16.png"   "$IS/icon_16x16.png"
cp "$SRC/icon_32.png"   "$IS/icon_16x16@2x.png"
cp "$SRC/icon_32.png"   "$IS/icon_32x32.png"
cp "$SRC/icon_64.png"   "$IS/icon_32x32@2x.png"
cp "$SRC/icon_128.png"  "$IS/icon_128x128.png"
cp "$SRC/icon_256.png"  "$IS/icon_128x128@2x.png"
cp "$SRC/icon_256.png"  "$IS/icon_256x256.png"
cp "$SRC/icon_512.png"  "$IS/icon_256x256@2x.png"
cp "$SRC/icon_512.png"  "$IS/icon_512x512.png"
cp "$SRC/icon_1024.png" "$IS/icon_512x512@2x.png"

iconutil -c icns "$IS" -o "$OUT"
echo "wrote $OUT"
