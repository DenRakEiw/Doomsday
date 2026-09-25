#!/usr/bin/env bash
# Runs an exported build's smoke mode (docs/specs/release.md §8) and compares
# its outcome, day and hash with tools/sim_run.gd's run of the same seed and
# bot (§9.1). Exit code 0 means the build played the run it should have.
#
#   tools/ci/smoke_check.sh [build/linux/Doomsday.x86_64]
#
# The Godot executable for the reference run comes from $GODOT, otherwise
# `godot` on PATH. The smoke writes its result into the game's own user folder
# (release.md §5): $XDG_DATA_HOME/Doomsday, by default ~/.local/share/Doomsday.

set -euo pipefail

GODOT="${GODOT:-godot}"
BIN="${1:-build/linux/Doomsday.x86_64}"
RESULT="${XDG_DATA_HOME:-$HOME/.local/share}/Doomsday/smoke/result.json"

# One field of a flat JSON object, string or number, spaces allowed.
field() {
	printf '%s' "$1" | tr -d '\n\t' | grep -o "\"$2\": *\"\?[^,\"}]*" | head -n 1 \
		| sed 's/^[^:]*: *"\{0,1\}//'
}

rm -f "$RESULT"
# A non-zero exit (1 = an error was logged, 2 = the run did not end) fails here.
"$BIN" --headless -- --smoke
result="$(cat "$RESULT")"
reference="$("$GODOT" --headless --path . -s tools/sim_run.gd -- --seed=1 --policy=greedy \
	| grep '^{' | tail -n 1)"

status=0
for key in outcome hash; do
	got="$(field "$result" "$key")"
	want="$(field "$reference" "$key")"
	echo "$key: smoke=$got sim_run=$want"
	if [ -z "$got" ] || [ "$got" != "$want" ]; then
		status=1
	fi
done
got="$(field "$result" day)"
want="$(field "$reference" days)"
echo "day: smoke=$got sim_run=$want"
[ "$got" = "$want" ] || status=1
errors="$(field "$result" errors)"
echo "errors: $errors"
[ "$errors" = "0" ] || status=1
if [ "$status" -ne 0 ]; then
	echo "the exported build did not play the reference run"
fi
exit "$status"
