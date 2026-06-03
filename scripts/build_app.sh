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
if [[ -f "$ROOT/packaging/AppIcon.icns" ]]; then
    cp "$ROOT/packaging/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

RESOURCE_BUNDLE="$(find "$ROOT/.build" -path '*release*' -iname '*shouldrest.bundle' -type d | head -n 1)"
if [[ -n "${RESOURCE_BUNDLE:-}" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
    find "$RESOURCE_BUNDLE" -maxdepth 1 -type d -name "*.lproj" -exec cp -R {} "$RESOURCES/" \;
fi

chmod +x "$MACOS/shouldrest"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
CODESIGN_ARGS=(--force --sign "$SIGN_IDENTITY" --deep)
if [[ "${HARDENED_RUNTIME:-0}" == "1" ]]; then
    CODESIGN_ARGS+=(--options runtime)
fi

codesign "${CODESIGN_ARGS[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
