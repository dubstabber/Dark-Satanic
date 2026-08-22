#!/usr/bin/env bash
# Enforces the maintainability rules:
#   * src/**/*.gd and tests/**/*.gd line counts: NOTE > 300 (the CLAUDE.md ceiling — split it
#     when you next touch it), NOTE > 500 (refactor candidate), WARN > 700, FAIL > 900
#   * autoloads (EventBus/RunManager/SettingsManager) may only be referenced from
#     src/core/** and src/game/** (AudioManager.play via an exported AudioCue is the one exception,
#     so AudioManager is allowed everywhere).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
status=0

while IFS= read -r f; do
  n=$(wc -l < "$f")
  if (( n > 900 )); then echo "FAIL  $n lines  $f (must refactor)"; status=1
  elif (( n > 700 )); then echo "WARN  $n lines  $f (probably not well organised)"
  elif (( n > 500 )); then echo "NOTE  $n lines  $f (refactor candidate)"
  elif (( n > 300 )); then echo "NOTE  $n lines  $f (over the 300-line ceiling, split when next touched)"
  fi
done < <(find src tests -name '*.gd' -type f 2>/dev/null | sort)

bad=$(grep -rnE '\b(EventBus|RunManager|SettingsManager)\b' src --include='*.gd' \
  | grep -vE '^src/(core|game)/' || true)
if [[ -n "$bad" ]]; then
  echo "FAIL  autoload referenced outside src/core or src/game:"
  echo "$bad"
  status=1
fi

if (( status == 0 )); then echo "script size / autoload checks OK"; fi
exit $status
