#!/usr/bin/env bash
#
# Build the PermissionPilot demo as a signed .app BUNDLE with its own TCC identity.
#
# Why: `swift run PermissionPilotDemo` produces an unbundled, unsigned binary.
# macOS attributes its permission requests to the *responsible parent process*
# (e.g. your terminal or "claude"), so System Settings shows the wrong app and
# toggling a permission never reflects back to the demo. Running it as a signed
# .app launched via `open` gives it a stable identity — it appears as
# "PermissionPilot Demo" and permission toggles take effect (Accessibility live;
# Input Monitoring after the built-in Quit & Reopen).
#
# Usage:
#   Example/build-demo-app.sh [debug|release] [--open]
#
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root

CONFIG="debug"
OPEN=0
for arg in "$@"; do
  case "$arg" in
    --open)        OPEN=1 ;;
    release|debug) CONFIG="$arg" ;;
    *) echo "usage: $0 [debug|release] [--open]"; exit 2 ;;
  esac
done

PRODUCT="PermissionPilotDemo"
APP="$PWD/.build/PermissionPilot Demo.app"
PLIST="Example/PermissionPilotDemo/Info.plist"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG" --product "$PRODUCT"
BIN=".build/$CONFIG/$PRODUCT"

echo "▸ Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$PRODUCT"
cp "$PLIST" "$APP/Contents/Info.plist"

# Copy SwiftPM resource bundles (e.g. localizations) into the app so
# `Bundle.module` resolves at runtime. Without these the first localized lookup
# crashes — Bundle.module calls fatalError when it can't find its bundle.
shopt -s nullglob
for b in ".build/$CONFIG/"*.bundle; do
  cp -R "$b" "$APP/Contents/Resources/"
done
shopt -u nullglob

# --- Signing ---------------------------------------------------------------
# Why this matters: TCC ties a permission grant to the app's code signature. A
# real Apple identity gives a stable, trusted signature so grants stick and
# reflect (turn green). Ad-hoc has an unstable identity TCC won't reliably
# honor — used only as a last resort for a quick UI look.
real_identity() {
  # NB: awk (not BSD sed) — macOS sed lacks \| alternation, which silently
  # returned empty and forced an ad-hoc fallback even when an identity existed.
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development|Developer ID Application/ { print $2; exit }'
}

IDENTITY="$(real_identity || true)"
if [ -n "${IDENTITY:-}" ]; then
  echo "▸ Signing with Apple identity: $IDENTITY"
  codesign --force --options runtime --sign "$IDENTITY" "$APP" >/dev/null
else
  echo "▸ No Apple Development / Developer ID identity found — ad-hoc signing."
  echo "  TCC grants are unreliable when ad-hoc signed. Get a FREE identity via"
  echo "  Xcode ▸ Settings ▸ Accounts ▸ (add Apple ID) ▸ Manage Certificates ▸ + ▸ Apple Development,"
  echo "  then re-run this script."
  codesign --force --sign - "$APP" >/dev/null
fi

echo "✓ Built: $APP"
if [ "$OPEN" = "1" ]; then
  # Quit a previously-running instance so the rebuilt app launches fresh (no stacked windows).
  osascript -e 'quit app "PermissionPilot Demo"' >/dev/null 2>&1 || true
  pkill -f "PermissionPilot Demo.app/Contents/MacOS/PermissionPilotDemo" 2>/dev/null || true
  echo "▸ Launching…"
  open "$APP"
else
  echo "  Launch it (its own TCC identity — shows as “PermissionPilot Demo”):"
  echo "    open \"$APP\""
fi
