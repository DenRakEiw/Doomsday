#!/usr/bin/env bash
# Runs the headless test suite. Exit code 0 means every test passed.
#
# The Godot executable comes from $GODOT, otherwise `godot` on PATH. On Windows
# point GODOT at the *_console.exe* build or the headless output never reaches
# the terminal.
#
# Extra arguments are passed straight to GUT, e.g.
#   tools/test.sh -gtest=res://tests/unit/test_smoke.gd
#   tools/test.sh -gunit_test_name=test_spread

set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$GODOT" --headless --path "$ROOT" --import

# --import does not parse scripts, and GUT only compiles what a test touches, so
# every script is checked in between.
"$GODOT" --headless --path "$ROOT" -s tools/check_scripts.gd

"$GODOT" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json -gexit "$@"
