#!/bin/bash
# Assemble Manifest.app from Mac/.engine + the bundle sources in this folder.
# Usage: dev/mac-app/build.sh [output_dir]   (default: dev/mac-app/build)
set -e
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$REPO/dev/mac-app"
OUT="${1:-$SRC/build}"
APP="$OUT/Manifest.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$SRC/Info.plist" "$APP/Contents/Info.plist"
cp "$SRC/bootstrap.sh" "$APP/Contents/MacOS/Manifest"
chmod +x "$APP/Contents/MacOS/Manifest"
[ -f "$SRC/icon.icns" ] && cp "$SRC/icon.icns" "$APP/Contents/Resources/icon.icns"

# Bundle the engine SOURCE (no venv / token-helper / downloads — built on first run).
rsync -a --exclude venv --exclude pot-provider --exclude downloads --exclude __pycache__ \
  "$REPO/Mac/.engine/" "$APP/Contents/Resources/engine/"

# Stamp the build commit so the self-updater has a baseline.
git -C "$REPO" rev-parse HEAD > "$APP/Contents/Resources/engine/.commit" 2>/dev/null || true

echo "Built: $APP"
