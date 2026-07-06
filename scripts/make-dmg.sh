#!/bin/bash
# scripts/make-dmg.sh — stage the Release app into a DMG (D71, phase-7 spec §7C).
# Dev-signed by default; set SIGN_IDENTITY to a "Developer ID Application" cert
# to re-sign with the hardened runtime (notarization prerequisite). Note: a
# Developer ID re-sign changes the code signature, so local TCC grants
# invalidate (Q2) — release builds are for distribution, not the dev machine.
set -euo pipefail

APP="build/Build/Products/Release/LotusScribe.app"
STAGING="build/dmg-staging"
DIST="dist"

if [ ! -d "$APP" ]; then
  echo "make-dmg: $APP not found — run 'make release' first." >&2
  exit 1
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$DIST"
cp -R "$APP" "$STAGING/LotusScribe.app"
ln -s /Applications "$STAGING/Applications"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$STAGING/LotusScribe.app"
else
  echo "make-dmg: SIGN_IDENTITY not set — shipping the dev-signed app."
fi

hdiutil create -volname LotusScribe -srcfolder "$STAGING" -ov -format UDZO \
  "$DIST/LotusScribe-$VERSION.dmg"
