#!/usr/bin/env bash
# Runs the GUT suite headless. Usage: tools/run_tests.sh [extra -g options...]
#   e.g. tools/run_tests.sh -gdir=res://tests/unit/ -gselect=wave_table
# Env: GODOT_BIN (default ./Godot_v4.7.1-stable_linux.x86_64), SKIP_IMPORT=1, FIXED_FPS=60
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/Godot_v4.7.1-stable_linux.x86_64}"
JUNIT_DIR="$ROOT/test_results"
FIXED_FPS="${FIXED_FPS:-60}"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "error: Godot binary not found or not executable: $GODOT_BIN (set GODOT_BIN)" >&2
  exit 2
fi

mkdir -p "$JUNIT_DIR"
rm -f "$JUNIT_DIR/junit.xml"

if [[ "${SKIP_IMPORT:-0}" != "1" ]]; then
  echo "==> Importing resources"
  "$GODOT_BIN" --headless --path "$ROOT" --import --quiet
fi

echo "==> Running GUT"
set +e
"$GODOT_BIN" --headless --path "$ROOT" \
  --fixed-fps "$FIXED_FPS" \
  -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://.gutconfig.json \
  -gjunit_xml_file=res://test_results/junit.xml \
  -gexit \
  "$@"
STATUS=$?
set -e

if [[ ! -f "$JUNIT_DIR/junit.xml" ]]; then
  echo "error: GUT did not produce $JUNIT_DIR/junit.xml (runner crashed?)" >&2
  exit 1
fi
echo "==> GUT exit status: $STATUS"
exit "$STATUS"
