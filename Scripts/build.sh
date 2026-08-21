#!/bin/sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$ROOT/CursorNotch.xcodeproj/project.pbxproj" ]; then
  echo "Run this script from the Cursor Notch repo (the folder that contains Scripts/ and CursorNotch.xcodeproj)." >&2
  echo "Current repo root resolved to: $ROOT" >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode from the App Store, then run: xcode-select --install" >&2
  exit 1
fi

DEST="${1:-"$ROOT/dist"}"
mkdir -p "$DEST"
echo "Building Cursor Notch from $ROOT"

xcodebuild \
  -project "$ROOT/CursorNotch.xcodeproj" \
  -scheme CursorNotch \
  -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$(find "$ROOT/build/DerivedData/Build/Products/Release" -maxdepth 1 -name 'Cursor Notch.app' | head -n 1)"
if [ -z "$APP" ]; then
  echo "Release app was not produced." >&2
  exit 1
fi

rm -rf "$DEST/Cursor Notch.app"
cp -R "$APP" "$DEST/Cursor Notch.app"
echo "Built $DEST/Cursor Notch.app"
