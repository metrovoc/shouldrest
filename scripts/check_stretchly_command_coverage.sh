#!/usr/bin/env bash
set -euo pipefail

stretchly_commands="${1:-/tmp/stretchly-research/app/utils/commands.js}"
audit_doc="${2:-docs/stretchly-feature-audit.md}"

if [[ ! -f "$stretchly_commands" ]]; then
  echo "Stretchly commands file not found: $stretchly_commands" >&2
  exit 2
fi

if [[ ! -f "$audit_doc" ]]; then
  echo "Audit document not found: $audit_doc" >&2
  exit 2
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

sed -n '/^const allCommands = {$/,/^const allExamples = /p' "$stretchly_commands" \
  | sed -n 's/^  \([A-Za-z0-9_][A-Za-z0-9_]*\): {.*/\1/p' > "$tmpdir/upstream.raw"
sed -n '/^## Stretchly Command Coverage$/,/^## Required Superset Surface$/p' "$audit_doc" \
  | sed -n 's/^| `\([^`][^`]*\)` |.*/\1/p' > "$tmpdir/covered.raw"

duplicate_upstream="$(sort "$tmpdir/upstream.raw" | uniq -d)"
duplicate_covered="$(sort "$tmpdir/covered.raw" | uniq -d)"
if [[ -n "$duplicate_upstream" || -n "$duplicate_covered" ]]; then
  if [[ -n "$duplicate_upstream" ]]; then
    echo "Duplicate commands in Stretchly command source:" >&2
    echo "$duplicate_upstream" >&2
  fi
  if [[ -n "$duplicate_covered" ]]; then
    echo "Duplicate commands in audit coverage table:" >&2
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
    echo "Missing Stretchly command coverage:" >&2
    echo "$missing" >&2
  fi
  if [[ -n "$extra" ]]; then
    echo "Audit document contains commands not present in Stretchly command source:" >&2
    echo "$extra" >&2
  fi
  exit 1
fi

count="$(wc -l < "$tmpdir/upstream" | tr -d ' ')"
echo "Stretchly command coverage OK: $count commands"
