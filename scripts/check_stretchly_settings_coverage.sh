#!/usr/bin/env bash
set -euo pipefail

stretchly_settings="${1:-/tmp/stretchly-research/app/utils/defaultSettings.js}"
audit_doc="${2:-docs/stretchly-feature-audit.md}"

if [[ ! -f "$stretchly_settings" ]]; then
  echo "Stretchly settings file not found: $stretchly_settings" >&2
  exit 2
fi

if [[ ! -f "$audit_doc" ]]; then
  echo "Audit document not found: $audit_doc" >&2
  exit 2
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

sed -n 's/^  \([A-Za-z0-9_][A-Za-z0-9_]*\):.*/\1/p' "$stretchly_settings" > "$tmpdir/upstream.raw"
sed -n '/^## Stretchly Settings-Key Coverage$/,/^## Required Superset Surface$/p' "$audit_doc" \
  | sed -n 's/^| `\([^`][^`]*\)` |.*/\1/p' > "$tmpdir/covered.raw"

duplicate_upstream="$(sort "$tmpdir/upstream.raw" | uniq -d)"
duplicate_covered="$(sort "$tmpdir/covered.raw" | uniq -d)"
if [[ -n "$duplicate_upstream" || -n "$duplicate_covered" ]]; then
  if [[ -n "$duplicate_upstream" ]]; then
    echo "Duplicate keys in Stretchly default settings:" >&2
    echo "$duplicate_upstream" >&2
  fi
  if [[ -n "$duplicate_covered" ]]; then
    echo "Duplicate keys in audit coverage table:" >&2
    echo "$duplicate_covered" >&2
  fi
  exit 1
fi

sort "$tmpdir/upstream.raw" > "$tmpdir/upstream"
sort "$tmpdir/covered.raw" > "$tmpdir/covered"

missing="$(comm -23 "$tmpdir/upstream" "$tmpdir/covered" || true)"
extra="$(comm -13 "$tmpdir/upstream" "$tmpdir/covered" || true)"

if [[ -n "$missing" || -n "$extra" ]]; then
  if [[ -n "$missing" ]]; then
    echo "Missing Stretchly setting coverage:" >&2
    echo "$missing" >&2
  fi
  if [[ -n "$extra" ]]; then
    echo "Audit document contains keys not present in Stretchly default settings:" >&2
    echo "$extra" >&2
  fi
  exit 1
fi

count="$(wc -l < "$tmpdir/upstream" | tr -d ' ')"
echo "Stretchly settings coverage OK: $count keys"
