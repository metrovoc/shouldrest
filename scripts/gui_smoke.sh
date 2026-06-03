#!/usr/bin/env bash
set -euo pipefail

app_path="${1:-dist/ShouldRest.app}"
timeout_seconds="${SHOULDREST_SMOKE_TIMEOUT:-20}"

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 2
fi

executable="$app_path/Contents/MacOS/shouldrest"
if [[ ! -x "$executable" ]]; then
  echo "App executable not found or not executable: $executable" >&2
  exit 2
fi

existing_pids="$(pgrep -x shouldrest || true)"
if [[ -n "$existing_pids" && "${ALLOW_EXISTING_SHOULDREST:-0}" != "1" ]]; then
  echo "Existing shouldrest process detected; quit it first or set ALLOW_EXISTING_SHOULDREST=1." >&2
  echo "$existing_pids" >&2
  exit 2
fi

support_dir="$(mktemp -d "${TMPDIR:-/tmp}/shouldrest-smoke.XXXXXX")"
pid=""
automation_pid=""

cleanup() {
  if [[ -n "$automation_pid" ]] && kill -0 "$automation_pid" 2>/dev/null; then
    kill "$automation_pid" 2>/dev/null || true
    wait "$automation_pid" 2>/dev/null || true
  fi
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    for _ in {1..20}; do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 0.1
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$support_dir"
}
trap cleanup EXIT

SHOULDREST_SUPPORT_DIR="$support_dir" "$executable" > "$support_dir/stdout.log" 2> "$support_dir/stderr.log" &
pid="$!"

attempts=$((timeout_seconds * 2))
welcome_seen=0
for ((attempt = 1; attempt <= attempts; attempt++)); do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "ShouldRest exited before the welcome window appeared." >&2
    cat "$support_dir/stdout.log" >&2 || true
    cat "$support_dir/stderr.log" >&2 || true
    exit 1
  fi

  windows="$(swift scripts/list_windows.swift || true)"
  if grep -Eq 'name=(Welcome to ShouldRest|欢迎使用 ShouldRest)' <<< "$windows"; then
    if ! grep -q "Onboarding shown" "$support_dir/logs/shouldrest.log" 2>/dev/null; then
      echo "Welcome window appeared, but smoke log did not confirm onboarding in the temporary support directory." >&2
      cat "$support_dir/logs/shouldrest.log" >&2 || true
      exit 1
    fi
    welcome_seen=1
    break
  fi

  sleep 0.5
done

if [[ "$welcome_seen" != "1" ]]; then
  echo "Timed out waiting for first-run welcome window." >&2
  echo "Observed ShouldRest windows:" >&2
  swift scripts/list_windows.swift >&2 || true
  echo "stdout:" >&2
  cat "$support_dir/stdout.log" >&2 || true
  echo "stderr:" >&2
  cat "$support_dir/stderr.log" >&2 || true
  exit 1
fi

SHOULDREST_SUPPORT_DIR="$support_dir" "$executable" preferences >> "$support_dir/stdout.log" 2>> "$support_dir/stderr.log" &
automation_pid="$!"

preferences_seen=0
for ((attempt = 1; attempt <= attempts; attempt++)); do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "ShouldRest exited before the preferences window appeared." >&2
    cat "$support_dir/stdout.log" >&2 || true
    cat "$support_dir/stderr.log" >&2 || true
    exit 1
  fi

  windows="$(swift scripts/list_windows.swift || true)"
  if grep -Eq 'name=(ShouldRest Preferences|ShouldRest 偏好设置)' <<< "$windows"; then
    if ! grep -Eq "Handled (automation|launch automation) command preferences" "$support_dir/logs/shouldrest.log" 2>/dev/null; then
      echo "Preferences window appeared, but smoke log did not confirm preferences automation." >&2
      cat "$support_dir/logs/shouldrest.log" >&2 || true
      exit 1
    fi
    preferences_seen=1
    break
  fi

  sleep 0.5
done

if [[ "$preferences_seen" != "1" ]]; then
  echo "Timed out waiting for preferences window." >&2
  echo "Observed ShouldRest windows:" >&2
  swift scripts/list_windows.swift >&2 || true
  echo "stdout:" >&2
  cat "$support_dir/stdout.log" >&2 || true
  echo "stderr:" >&2
  cat "$support_dir/stderr.log" >&2 || true
  exit 1
fi

echo "GUI smoke OK: first-run welcome and preferences windows appeared with temporary support directory."
