#!/usr/bin/env bash
#
# Build the PermissionPilot demo as a downloadable .dmg for evaluation.
#
# The app is **ad-hoc signed** (this project uses no paid Developer ID, so it is
# not notarized). It runs on any Mac after a one-time Gatekeeper bypass — the
# README explains right-click ▸ Open / `xattr -dr com.apple.quarantine`. Ad-hoc
# gives a *stable* signature for a fixed binary, so TCC grants persist for the
# downloaded build. Audience: macOS developers evaluating the SDK.
#
# Universal (arm64 + x86_64) so it runs on both Apple Silicon and Intel.
#
# Usage: Example/make-dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PRODUCT="PermissionPilotDemo"
APP_NAME="PermissionPilot Demo"
PLIST="Example/PermissionPilotDemo/Info.plist"
STAGING=".build/dmg-staging"
APP="$STAGING/$APP_NAME.app"
DMG=".build/PermissionPilot-Demo.dmg"

ARCHS=(--arch arm64 --arch x86_64)

echo "▸ Building universal release (arm64 + x86_64)…"
swift build -c release "${ARCHS[@]}" --product "$PRODUCT"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

echo "▸ Assembling app bundle…"
rm -rf "$STAGING"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
cp "$PLIST" "$APP/Contents/Info.plist"
# SwiftPM resource bundles (localizations) — required or Bundle.module crashes.
shopt -s nullglob
for b in "$BIN_DIR/"*.bundle; do cp -R "$b" "$APP/Contents/Resources/"; done
shopt -u nullglob

echo "▸ Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "▸ Building .dmg…"
ln -s /Applications "$STAGING/Applications"   # drag-to-install affordance
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

echo "✓ Built: $DMG"
echo "  Size: $(du -h "$DMG" | cut -f1)"
