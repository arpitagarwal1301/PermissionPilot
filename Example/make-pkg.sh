#!/usr/bin/env bash
#
# Build the PermissionPilot demo as a .pkg installer (universal, ad-hoc signed app).
#
# Why a .pkg in addition to the .dmg: the installer drops the app into
# /Applications, and pkg-installed files are NOT quarantined — so the app then
# launches cleanly with no per-launch Gatekeeper prompt and no Terminal. The .pkg
# itself is unsigned (this repo ships no paid Developer ID), so macOS asks to
# approve the installer ONCE — right-click the .pkg → Open, or
# System Settings → Privacy & Security → Open Anyway (a GUI step, no Terminal).
#
# Universal (arm64 + x86_64). Usage: Example/make-pkg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PRODUCT="PermissionPilotDemo"
APP_NAME="PermissionPilot Demo"
PLIST="Example/PermissionPilotDemo/Info.plist"
STAGING=".build/pkg-staging"
APP="$STAGING/$APP_NAME.app"
PKG=".build/PermissionPilot-Demo.pkg"
ARCHS=(--arch arm64 --arch x86_64)

echo "▸ Building universal release (arm64 + x86_64)…"
swift build -c release "${ARCHS[@]}" --product "$PRODUCT"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

echo "▸ Assembling app bundle…"
rm -rf "$STAGING"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$PRODUCT" "$APP/Contents/MacOS/$PRODUCT"
cp "$PLIST" "$APP/Contents/Info.plist"
shopt -s nullglob
for b in "$BIN_DIR/"*.bundle; do cp -R "$b" "$APP/Contents/Resources/"; done   # localizations
shopt -u nullglob

echo "▸ Ad-hoc signing app…"
codesign --force --deep --sign - "$APP"

echo "▸ Building .pkg (installs to /Applications)…"
rm -f "$PKG"
pkgbuild --root "$STAGING" \
  --install-location /Applications \
  --identifier com.permissionpilot.demo.pkg \
  --version 0.1.0 \
  "$PKG" >/dev/null

echo "✓ Built: $PKG"
echo "  Size: $(du -h "$PKG" | cut -f1)"
