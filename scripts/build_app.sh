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

SOURCE_RESOURCES="$ROOT/Sources/shouldrest/Resources"
RESOURCE_BUNDLE="$RESOURCES/ShouldRest_shouldrest.bundle"
mkdir -p "$RESOURCE_BUNDLE"
cp "$SOURCE_RESOURCES/ThirdPartyNotices.txt" "$RESOURCE_BUNDLE/"
cp "$SOURCE_RESOURCES"/audio/*.wav "$RESOURCE_BUNDLE/"
for lproj in "$SOURCE_RESOURCES"/*.lproj; do
    lproj_name="$(basename "$lproj" | tr '[:upper:]' '[:lower:]')"
    rm -rf "$RESOURCE_BUNDLE/$lproj_name" "$RESOURCES/$lproj_name"
    cp -R "$lproj" "$RESOURCE_BUNDLE/$lproj_name"
    cp -R "$lproj" "$RESOURCES/$lproj_name"
done

chmod +x "$MACOS/shouldrest"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
CODESIGN_ARGS=(--force --sign "$SIGN_IDENTITY" --deep)
if [[ "${HARDENED_RUNTIME:-0}" == "1" ]]; then
    CODESIGN_ARGS+=(--options runtime)
fi

codesign "${CODESIGN_ARGS[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
