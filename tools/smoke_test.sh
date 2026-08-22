#!/usr/bin/env bash
# Boots the real game binary headless and fails on any engine/script error in the log.
# Env: GODOT_BIN, FRAMES (default 180)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/Godot_v4.7.1-stable_linux.x86_64}"
FRAMES="${FRAMES:-180}"
LOG="$ROOT/test_results/smoke.log"
mkdir -p "$(dirname "$LOG")"; : > "$LOG"

run_case() {  # name, extra args...
  local name="$1"; shift
  echo "==> smoke: $name"
  "$GODOT_BIN" --headless --path "$ROOT" --fixed-fps 60 --quit-after "$FRAMES" "$@" 2>&1 | tee -a "$LOG"
}
run_case "main menu"
run_case "autostart run" -- --autostart

# Godot 4.7.1 reports a playing ogg stream as "resources still in use at exit" even after
# stop() + stream = null (reproduced with a bare AudioStreamPlayer); it is an engine
# teardown artifact, so that single line is tolerated.
if grep -vE "resources still in use at exit" "$LOG" | grep -E "SCRIPT ERROR|USER ERROR|^ERROR:|Parse Error|Failed to load"; then
  echo "smoke test FAILED: errors found in log" >&2; exit 1
fi
echo "smoke test OK"
