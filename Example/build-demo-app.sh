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

# Prefer a real signing identity (grants persist across rebuilds); otherwise
# ad-hoc sign (works for this session; the grant may reset when you rebuild).
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Apple Development[^"]*\|Developer ID Application[^"]*\)".*/\1/p' | head -1 || true)"
if [ -n "${IDENTITY:-}" ]; then
  echo "▸ Signing with: $IDENTITY"
  codesign --force --options runtime --sign "$IDENTITY" "$APP" >/dev/null
else
  echo "▸ No Developer identity found — ad-hoc signing (grant may reset on rebuild)."
  codesign --force --sign - "$APP" >/dev/null
fi

echo "✓ Built: $APP"
if [ "$OPEN" = "1" ]; then
  echo "▸ Launching…"
  open "$APP"
else
  echo "  Launch it (its own TCC identity — shows as “PermissionPilot Demo”):"
  echo "    open \"$APP\""
fi
