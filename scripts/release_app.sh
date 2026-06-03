#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
APP_NAME="ShouldRest"
APP_DIR="$DIST_DIR/$APP_NAME.app"
INFO_PLIST="$ROOT/packaging/Info.plist"

version="$("/usr/libexec/PlistBuddy" -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
build_number="$("/usr/libexec/PlistBuddy" -c "Print :CFBundleVersion" "$INFO_PLIST")"
dmg_path="$DIST_DIR/$APP_NAME-$version.dmg"
staging_dir="$DIST_DIR/dmg-root"

detect_developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null |
        awk -F '"' '/Developer ID Application/ { print $2; exit }'
}

sign_identity="${SIGN_IDENTITY:-}"
if [[ -z "$sign_identity" ]]; then
    sign_identity="$(detect_developer_id_identity)"
fi

if [[ -z "$sign_identity" ]]; then
    if [[ "${ALLOW_ADHOC:-0}" == "1" ]]; then
        sign_identity="-"
    else
        echo "No Developer ID Application identity found." >&2
        echo "Set SIGN_IDENTITY or run with ALLOW_ADHOC=1 for a local dry-run DMG." >&2
        exit 1
    fi
fi

if [[ "$sign_identity" == "-" && "${NOTARIZE:-0}" == "1" ]]; then
    echo "Notarization requires Developer ID signing; ad-hoc signing is not accepted." >&2
    exit 1
fi

export SIGN_IDENTITY="$sign_identity"
export HARDENED_RUNTIME="${HARDENED_RUNTIME:-1}"

"$ROOT/scripts/build_app.sh" >/dev/null

codesign --verify --deep --strict "$APP_DIR"
codesign --display --verbose=2 "$APP_DIR"

rm -rf "$staging_dir" "$dmg_path"
mkdir -p "$staging_dir"
ditto "$APP_DIR" "$staging_dir/$APP_NAME.app"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
    -volname "$APP_NAME $version" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$dmg_path" >/dev/null
rm -rf "$staging_dir"

if [[ "$sign_identity" != "-" ]]; then
    codesign --force --sign "$sign_identity" "$dmg_path" >/dev/null
    codesign --verify --strict "$dmg_path"
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
    if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
        xcrun notarytool submit "$dmg_path" \
            --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
            --wait
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
        xcrun notarytool submit "$dmg_path" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_SPECIFIC_PASSWORD" \
            --wait
    else
        echo "NOTARIZE=1 requires NOTARY_KEYCHAIN_PROFILE or APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD." >&2
        exit 1
    fi
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
fi

echo "$APP_NAME $version ($build_number)"
echo "$APP_DIR"
echo "$dmg_path"
