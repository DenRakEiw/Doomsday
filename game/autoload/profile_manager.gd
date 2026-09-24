extends Node
## What persists between runs (`replayability.md` §6, `screens-full.md` §5):
## `user://profile.json`, versioned JSON like a save and never a resource.
##
## Counters only. **Unlocks derive, they are not stored**: an architecture's rule
## and the directive slot count are computed from the counters, so a hand-edited
## or corrupt file cannot unlock more than its counters say. A player's run is
## counted when it reaches an outcome — a bot's never, and a loaded run that had
## already ended never again (`Game` only reports a run that ends in front of it).
##
## The core knows nothing of this file. The autoload name is the global, so no
## `class_name`.

const PATH: String = "user://profile.json"
const VERSION: int = 1
## `screens-full.md` §5: the history keeps this many runs, newest first.
const HISTORY_MAX: int = 20
const WIN_PREFIX: String = "win_"

const KEY_VERSION: String = "version"
const KEY_RUNS: String = "runs_completed"
const KEY_WON: String = "runs_won"
const KEY_WINS_BY_OUTCOME: String = "wins_by_outcome"
const KEY_BY_ARCHITECTURE: String = "by_architecture"
const KEY_LAST_SETUP: String = "last_setup"
const KEY_BOOT_SEEN: String = "boot_seen"
const KEY_SEEN_UNLOCKS: String = "seen_unlocks"
const KEY_ENDINGS_SEEN: String = "endings_seen"
const KEY_CODEX: String = "codex"
const KEY_HISTORY: String = "history"
## `by_architecture` entry fields.
const ARCH_RUNS: String = "runs"
const ARCH_WINS: String = "wins"
const ARCH_BEST_DAYS: String = "best_days"
## The Codex tabs a run collects into (§5.1); architectures and endings derive.
const CODEX_TABS: Array[String] = ["regions", "factions", "tech", "characters", "statuses"]
## `architectures.json`'s unlock rules (§8.1).
const UNLOCK_RUNS: String = "runs_completed"
const UNLOCK_WINS: String = "wins"
const UNLOCK_WINS_BY_OUTCOME: String = "wins_by_outcome"

## Where the file lives. The test suite points it elsewhere before it runs, so a
## test run never counts into the player's profile (`tests/support/pre_run.gd`).
var path: String = PATH
var runs_completed: int = 0
var runs_won: int = 0
var wins_by_outcome: Dictionary[String, int] = {}
## Architecture id → `{runs, wins, best_days}` (best = fewest days to a win, 0 none).
var by_architecture: Dictionary[String, Dictionary] = {}
var last_setup: RunSetup = RunSetup.new()
var boot_seen: bool = false
var seen_unlocks: Array[String] = []
var endings_seen: Array[String] = []
## Tab → ids, a set in file order.
var codex: Dictionary[String, Array] = {}
var history: Array[Dictionary] = []


func _ready() -> void:
	_apply(_read())
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)


# ------------------------------------------------------------------- unlocks


## Whether the counters have earned this architecture (§2.1).
func is_unlocked(def: ArchitectureDef) -> bool:
	return rule_met(def.unlock, runs_completed, runs_won, wins_by_outcome)


## `unlock` against the counters: `{}` always; otherwise its one rule.
static func rule_met(unlock: Dictionary, runs: int, wins: int,
		by_outcome: Dictionary[String, int]) -> bool:
	if unlock.has(UNLOCK_RUNS):
		return runs >= int(unlock[UNLOCK_RUNS])
	if unlock.has(UNLOCK_WINS):
		return wins >= int(unlock[UNLOCK_WINS])
	if unlock.has(UNLOCK_WINS_BY_OUTCOME):
		var needed: Dictionary = unlock[UNLOCK_WINS_BY_OUTCOME]
		for outcome: Variant in needed:
			if int(by_outcome.get(str(outcome), 0)) < int(needed[outcome]):
				return false
	return true


## §4: slot *n* unlocks after *n* completed runs.
func slots_unlocked(slot_count: int) -> int:
	return mini(slot_count, runs_completed)


# ------------------------------------------------------------------- the run


## Counts one finished run: the counters, its architecture's row, the history,
## the ending. `outcome` is an outcome id; `variant` the ending's (S5.6), or the
## outcome itself until endings have variants.
func record_run(sim: Simulation, outcome: String, variant: String = "") -> void:
	var world: World = sim.world
	var won: bool = outcome.begins_with(WIN_PREFIX)
	var days: int = world.day - world.origin_day
	runs_completed += 1
	if won:
		runs_won += 1
		wins_by_outcome[outcome] = int(wins_by_outcome.get(outcome, 0)) + 1
	var architecture: String = world.setup.architecture
	var row: Dictionary = by_architecture.get(architecture, {ARCH_RUNS: 0, ARCH_WINS: 0,
		ARCH_BEST_DAYS: 0})
	row[ARCH_RUNS] = int(row[ARCH_RUNS]) + 1
	if won:
		row[ARCH_WINS] = int(row[ARCH_WINS]) + 1
		var best: int = int(row[ARCH_BEST_DAYS])
		row[ARCH_BEST_DAYS] = days if best <= 0 else mini(best, days)
	by_architecture[architecture] = row
	var ending: String = variant if not variant.is_empty() else outcome
	if not endings_seen.has(ending):
		endings_seen.append(ending)
	history.push_front(_history_entry(sim, outcome, ending, days))
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)
	write()


## Adds ids to a Codex tab, each once, in the order they came (§5.1).
func merge_codex(tab: String, ids: Array[String]) -> void:
	if not CODEX_TABS.has(tab):
		return
	var known: Array = codex.get(tab, [])
	var changed: bool = false
	for id: String in ids:
		if not known.has(id):
			known.append(id)
			changed = true
	codex[tab] = known
	if changed:
		write()


func mark_boot_seen() -> void:
	if boot_seen:
		return
	boot_seen = true
	write()


## An unlock the player has looked at: its *New* chip goes (§4.1).
func mark_unlock_seen(id: String) -> void:
	if seen_unlocks.has(id):
		return
	seen_unlocks.append(id)
	write()


## Settings' *Reset progress* (§6.3): every counter back to nothing. Saves stay.
func reset() -> void:
	_apply(null)
	write()


func to_dict() -> Dictionary:
	var arch: Dictionary = {}
	for id: String in by_architecture:
		arch[id] = by_architecture[id].duplicate()
	var codex_out: Dictionary = {}
	for tab: String in codex:
		codex_out[tab] = (codex[tab] as Array).duplicate()
	var history_out: Array = []
	for entry: Dictionary in history:
		history_out.append(entry.duplicate(true))
	return {
		KEY_VERSION: VERSION,
		KEY_RUNS: runs_completed,
		KEY_WON: runs_won,
		KEY_WINS_BY_OUTCOME: wins_by_outcome.duplicate(),
		KEY_BY_ARCHITECTURE: arch,
		KEY_LAST_SETUP: last_setup.to_dict(),
		KEY_BOOT_SEEN: boot_seen,
		KEY_SEEN_UNLOCKS: seen_unlocks.duplicate(),
		KEY_ENDINGS_SEEN: endings_seen.duplicate(),
		KEY_CODEX: codex_out,
		KEY_HISTORY: history_out,
	}


func write() -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		# A read-only user directory is the player's problem, not a crash of ours.
		push_warning("profile: cannot write %s (%d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(to_dict(), "\t", true, true))


# ----------------------------------------------------------------- reading


## Every field from `raw`, each falling back to empty when it is missing or of
## the wrong type — a corrupt file reads as a fresh profile, field by field.
## Content ids are not checked here: an id this build lacks is simply never
## looked up (the Codex and the unlock rules ask by the content's ids).
func _apply(raw: Variant) -> void:
	var d: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	runs_completed = _whole(d, KEY_RUNS)
	runs_won = mini(_whole(d, KEY_WON), runs_completed)
	wins_by_outcome = _counts(d.get(KEY_WINS_BY_OUTCOME))
	by_architecture = {}
	if typeof(d.get(KEY_BY_ARCHITECTURE)) == TYPE_DICTIONARY:
		var arch: Dictionary = d[KEY_BY_ARCHITECTURE]
		for id: Variant in arch:
			if typeof(arch[id]) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = arch[id]
			by_architecture[str(id)] = {ARCH_RUNS: _whole(row, ARCH_RUNS),
				ARCH_WINS: _whole(row, ARCH_WINS), ARCH_BEST_DAYS: _whole(row, ARCH_BEST_DAYS)}
	last_setup = RunSetup.new()
	if typeof(d.get(KEY_LAST_SETUP)) == TYPE_DICTIONARY:
		var setup: RunSetup = RunSetup.from_dict(d[KEY_LAST_SETUP])
		if setup != null:
			last_setup = setup
	boot_seen = typeof(d.get(KEY_BOOT_SEEN)) == TYPE_BOOL and bool(d[KEY_BOOT_SEEN])
	seen_unlocks = _strings(d.get(KEY_SEEN_UNLOCKS))
	endings_seen = _strings(d.get(KEY_ENDINGS_SEEN))
	codex = {}
	if typeof(d.get(KEY_CODEX)) == TYPE_DICTIONARY:
		var tabs: Dictionary = d[KEY_CODEX]
		for tab: String in CODEX_TABS:
			codex[tab] = _strings(tabs.get(tab))
	history = []
	if typeof(d.get(KEY_HISTORY)) == TYPE_ARRAY:
		for entry: Variant in d[KEY_HISTORY]:
			if typeof(entry) == TYPE_DICTIONARY and history.size() < HISTORY_MAX:
				history.append(_read_entry(entry))


## Points the profile at another file and reads it — the test suite's door.
func use_path(new_path: String) -> void:
	path = new_path
	_apply(_read())


func _read() -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


## JSON has no integers: a history entry's counts and region indices come back as
## whole numbers again, and a list of anything else reads as empty.
static func _read_entry(raw: Dictionary) -> Dictionary:
	var entry: Dictionary = raw.duplicate(true)
	for key: String in ["n", "days", "seed"]:
		entry[key] = _whole(raw, key)
	for key: String in ["regions", "controlled"]:
		var indices: Array = []
		if typeof(raw.get(key)) == TYPE_ARRAY:
			for value: Variant in raw[key]:
				if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
					indices.append(int(value))
		entry[key] = indices
	return entry


static func _whole(d: Dictionary, key: String) -> int:
	var type: int = typeof(d.get(key))
	if type != TYPE_INT and type != TYPE_FLOAT:
		return 0
	return maxi(0, int(d[key]))


static func _counts(raw: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	for key: Variant in d:
		var value: int = _whole(d, str(key))
		if value > 0:
			out[str(key)] = value
	return out


static func _strings(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry: Variant in raw:
		if typeof(entry) == TYPE_STRING and not out.has(str(entry)):
			out.append(str(entry))
	return out


## §5: the run as the Statistics and the title's globe read it. `n` is the count
## with this run in it.
func _history_entry(sim: Simulation, outcome: String, ending: String,
		days: int) -> Dictionary:
	var world: World = sim.world
	var reached: Array = []
	var controlled: Array = []
	for i: int in range(1, world.regions.size()):
		if world.regions[i].seeded_day >= 0:
			reached.append(i)
		if world.regions[i].control >= sim.db.balance.control_complete:
			controlled.append(i)
	return {
		"n": runs_completed,
		"architecture": world.setup.architecture,
		"difficulty": world.setup.difficulty,
		"directives": world.setup.directives.duplicate(),
		"outcome": outcome,
		"variant": ending,
		"days": days,
		"seed": int(world.rng.seed_string()),
		"origin": "" if world.agent.origin == 0 else world.regions[world.agent.origin].def.id,
		"regions": reached,
		"controlled": controlled,
	}


# ------------------------------------------------------------------ signals


## The setup of a player's run is what the next *New run* opens on (§4).
func _on_run_started(_seed_value: int) -> void:
	if Game.sim == null or Game.policy != null:
		return
	last_setup = Game.sim.world.setup.duplicate_setup()
	write()


func _on_run_ended(outcome: String) -> void:
	if Game.sim == null or Game.policy != null:
		return
	record_run(Game.sim, outcome)
