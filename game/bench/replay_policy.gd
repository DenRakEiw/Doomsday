class_name ReplayPolicy
extends Policy
## A recorded benchmark run played again (docs/specs/benchmark.md §12.2): the
## entry's command log handed to the day loop, each command on its own day. It
## decides nothing and draws no random numbers — the world's stream is the only
## one, so the replay reaches the recorded state exactly when every command is
## accepted on the day it was recorded.
##
## Not registered in `Policy.create`: it needs an entry; `Game.start_spectating`
## builds it.

const ID: String = "replay"

var entry: BenchEntry = null
## The first day a logged command was refused or missed; -1 while the replay
## follows the recording.
var diverged_day: int = -1

## The commands as dictionaries, so each one handed out is a fresh object
## (`Simulation.apply` stamps `day` on the one it is given).
var _rows: Array[Dictionary] = []
## The day each row was recorded on, parallel to `_rows`.
var _days: Array[int] = []
var _cursor: int = 0
## Commands handed out so far; the simulation's log is this long when all of
## them were accepted.
var _handed: int = 0


func _init(p_entry: BenchEntry) -> void:
	entry = p_entry
	for command: Command in entry.commands:
		_rows.append(command.to_dict())
		_days.append(command.day)


func policy_id() -> String:
	return ID


func next_command(sim: Simulation) -> Command:
	var day: int = sim.world.day
	# A log shorter than what was handed out: the last command was refused.
	if sim.command_log.size() < _handed:
		_diverge(day)
		_handed = sim.command_log.size()
	# A command whose day has passed was never played — the run has left the
	# recording.
	while _cursor < _rows.size() and _days[_cursor] < day:
		_cursor += 1
		_diverge(day)
	if _cursor >= _rows.size() or _days[_cursor] != day:
		return null
	var command: Command = CommandCodec.from_dict(_rows[_cursor])
	_cursor += 1
	if command == null:
		# `BenchEntry.from_dict` decoded it once already; a row that no longer
		# decodes is skipped like a refused one.
		_diverge(day)
		return null
	_handed += 1
	return command


## The latest decision made on or before `day`, or null before the first one
## (and always for a bot entry, which has none).
func decision_at(day: int) -> BenchDecision:
	var index: int = decision_index(day)
	return null if index <= 0 else entry.decisions[index - 1]


## The 1-based index of `decision_at(day)`, 0 before the first decision.
func decision_index(day: int) -> int:
	var index: int = 0
	for i: int in entry.decisions.size():
		if entry.decisions[i].day > day:
			break
		index = i + 1
	return index


func _diverge(day: int) -> void:
	if diverged_day < 0:
		diverged_day = day
