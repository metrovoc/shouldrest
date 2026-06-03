#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_file="${1:-$ROOT/Sources/shouldrest/Resources/en.lproj/Localizable.strings}"
shift || true
localized_files=("$@")

if [[ ${#localized_files[@]} -eq 0 ]]; then
  localized_files=("$ROOT/Sources/shouldrest/Resources/zh-Hans.lproj/Localizable.strings")
fi

if [[ ! -f "$base_file" ]]; then
  echo "Base localization file missing: $base_file" >&2
  exit 2
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

extract_keys() {
  local file="$1"
  sed -n 's/^"\([^"]*\)"[[:space:]]*=.*/\1/p' "$file"
}

extract_keys "$base_file" > "$tmpdir/base.raw"
if [[ ! -s "$tmpdir/base.raw" ]]; then
  echo "No localization keys found in base file $base_file" >&2
  exit 1
fi
base_duplicates="$(sort "$tmpdir/base.raw" | uniq -d)"
if [[ -n "$base_duplicates" ]]; then
  echo "Duplicate localization keys in base file $base_file:" >&2
  echo "$base_duplicates" >&2
  exit 1
fi
sort "$tmpdir/base.raw" > "$tmpdir/base"
base_count="$(wc -l < "$tmpdir/base" | tr -d ' ')"

for file in "${localized_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Localization file missing: $file" >&2
    exit 2
  fi

  safe_name="$(basename "$(dirname "$file")")"
  extract_keys "$file" > "$tmpdir/$safe_name.raw"
  duplicates="$(sort "$tmpdir/$safe_name.raw" | uniq -d)"
  if [[ -n "$duplicates" ]]; then
    echo "Duplicate localization keys in $file:" >&2
    echo "$duplicates" >&2
    exit 1
  fi

  sort "$tmpdir/$safe_name.raw" > "$tmpdir/$safe_name"
  missing="$(comm -23 "$tmpdir/base" "$tmpdir/$safe_name" || true)"
  extra="$(comm -13 "$tmpdir/base" "$tmpdir/$safe_name" || true)"

  if [[ -n "$missing" || -n "$extra" ]]; then
    if [[ -n "$missing" ]]; then
      echo "Missing localization keys in $file:" >&2
      echo "$missing" >&2
    fi
    if [[ -n "$extra" ]]; then
      echo "Extra localization keys in $file:" >&2
      echo "$extra" >&2
    fi
    exit 1
  fi

  echo "Localization coverage OK: $safe_name has $base_count keys"
done
