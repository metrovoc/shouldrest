#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build -c release

APP_DIR="$ROOT/dist/ShouldRest.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$ROOT/.build/release/shouldrest" "$MACOS/shouldrest"
cp "$ROOT/packaging/Info.plist" "$CONTENTS/Info.plist"

RESOURCE_BUNDLE="$(find "$ROOT/.build" -path '*release*' -iname '*shouldrest.bundle' -type d | head -n 1)"
if [[ -n "${RESOURCE_BUNDLE:-}" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
fi

chmod +x "$MACOS/shouldrest"
echo "$APP_DIR"
