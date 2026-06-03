#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

stretchly_settings="${1:-/tmp/stretchly-research/app/utils/defaultSettings.js}"
app_dir="$ROOT/dist/ShouldRest.app"
info_plist="$app_dir/Contents/Info.plist"
resources_dir="$app_dir/Contents/Resources/ShouldRest_shouldrest.bundle"
version="$("/usr/libexec/PlistBuddy" -c "Print :CFBundleShortVersionString" "$ROOT/packaging/Info.plist")"
dmg_path="$ROOT/dist/ShouldRest-$version.dmg"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Required file missing: $path" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "Required directory missing: $path" >&2
    exit 1
  fi
}

echo "==> Checking Stretchly settings coverage"
"$ROOT/scripts/check_stretchly_settings_coverage.sh" "$stretchly_settings" "$ROOT/docs/stretchly-feature-audit.md"

echo "==> Checking patch whitespace"
git diff --check

echo "==> Running tests"
swift test

echo "==> Building app bundle"
"$ROOT/scripts/build_app.sh"

echo "==> Checking app bundle metadata"
require_file "$info_plist"
url_scheme="$("/usr/libexec/PlistBuddy" -c "Print :CFBundleURLTypes:0:CFBundleURLSchemes:0" "$info_plist")"
if [[ "$url_scheme" != "shouldrest" ]]; then
  echo "Unexpected URL scheme: $url_scheme" >&2
  exit 1
fi

bundle_id="$("/usr/libexec/PlistBuddy" -c "Print :CFBundleIdentifier" "$info_plist")"
if [[ "$bundle_id" != "dev.shouldrest.app" ]]; then
  echo "Unexpected bundle identifier: $bundle_id" >&2
  exit 1
fi

echo "==> Checking packaged resources"
require_dir "$resources_dir"
require_file "$resources_dir/en.lproj/Localizable.strings"
require_file "$resources_dir/zh-hans.lproj/Localizable.strings"
require_file "$resources_dir/ThirdPartyNotices.txt"
for sound in crystal-glass reverie silence tic-toc wind-chime; do
  require_file "$resources_dir/$sound.wav"
done

echo "==> Verifying app signature"
codesign --verify --deep --strict "$app_dir"

echo "==> Running first-run GUI smoke"
"$ROOT/scripts/gui_smoke.sh" "$app_dir"

echo "==> Building local release DMG"
ALLOW_ADHOC="${ALLOW_ADHOC:-1}" "$ROOT/scripts/release_app.sh"

echo "==> Verifying release DMG"
require_file "$dmg_path"
hdiutil verify "$dmg_path"

echo "Local release verification OK"
