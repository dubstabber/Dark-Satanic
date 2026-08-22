#!/usr/bin/env bash
# Run the game (or the editor with -e). Extra args pass through to Godot.
#   tools/run_game.sh                  # run the main scene
#   tools/run_game.sh -e               # open the editor
#   tools/run_game.sh res://x.tscn     # run a specific scene
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$ROOT/Godot_v4.7.1-stable_linux.x86_64}"
exec "$GODOT_BIN" --path "$ROOT" "$@"
