#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$ROOT/CursorNotch.xcodeproj/project.pbxproj" ]; then
  echo "Missing $ROOT/CursorNotch.xcodeproj/project.pbxproj" >&2
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode and select its Contents/Developer directory." >&2
  exit 1
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not using a full Xcode installation." >&2
  echo "Current developer directory: $(xcode-select -p 2>/dev/null || echo unknown)" >&2
  exit 1
fi

DEST="${1:-"$ROOT/dist"}"
DERIVED="$ROOT/build/DerivedData"
LOG="$ROOT/build/xcodebuild.log"
mkdir -p "$DEST" "$ROOT/build"

echo "Building Cursor Notch with $(xcodebuild -version | tr '\n' ' ')"
if ! xcodebuild \
  -project "$ROOT/CursorNotch.xcodeproj" \
  -scheme CursorNotch \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build >"$LOG" 2>&1; then
  echo "Build failed. Relevant diagnostics:" >&2
  /usr/bin/grep -E '(^|: )(error:|fatal error:)|\*\* BUILD FAILED \*\*' "$LOG" >&2 || true
  echo "Full log: $LOG" >&2
  exit 1
fi

APP="$DERIVED/Build/Products/Release/Cursor Notch.app"
if [ ! -d "$APP" ]; then
  echo "Build succeeded but the app was not found at: $APP" >&2
  echo "Full log: $LOG" >&2
  exit 1
fi

rm -rf "$DEST/Cursor Notch.app"
cp -R "$APP" "$DEST/Cursor Notch.app"
echo "Built $DEST/Cursor Notch.app"
