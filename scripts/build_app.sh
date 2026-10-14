#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build -c release

# DIST_DIR can point outside a synced folder whose file provider tags bundles,
# which codesign rejects.
APP_DIR="${DIST_DIR:-$ROOT/dist}/ShouldRest.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$ROOT/.build/release/shouldrest" "$MACOS/shouldrest"
# Drops the linker's debug map, which lists absolute object file paths and would
# publish the checkout location. The unstripped binary stays in .build.
strip -S "$MACOS/shouldrest"
cp "$ROOT/packaging/Info.plist" "$CONTENTS/Info.plist"

# Compiles the Icon Composer document and the accent color into Assets.car, plus
# AppIcon.icns for CFBundleIconFile.
ICON_PLIST="$(mktemp -t shouldrest-icon)"
if ! icon_log="$(xcrun actool "$ROOT/packaging/AppIcon.icon" "$ROOT/packaging/Assets.xcassets" \
    --compile "$RESOURCES" \
    --platform macosx \
    --target-device mac \
    --minimum-deployment-target "$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$ROOT/packaging/Info.plist")" \
    --app-icon AppIcon \
    --accent-color AccentColor \
    --output-partial-info-plist "$ICON_PLIST" \
    --output-format human-readable-text \
    --errors 2>&1)"; then
    echo "$icon_log" >&2
    rm -f "$ICON_PLIST"
    exit 1
fi
rm -f "$ICON_PLIST"

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
