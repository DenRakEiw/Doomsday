class_name RunSetup
extends RefCounted
## What a run is before its origin (`replayability.md` §1): an architecture, a
## loadout of directives, a difficulty and, from S5.8, a scenario. Fixed for the
## run; in the save and in the replay header, so a replay rebuilds the same run.
##
## Directives and difficulty are carried from S5.1 on and read from S5.3 and S5.4.

const DEFAULT_DIFFICULTY: String = DifficultyDef.DEFAULT_ID

var architecture: String = ArchitectureDef.DEFAULT_ID
## At most one per slot, only unlocked slots (the profile's check, S5.3).
var directives: Array[String] = []
var difficulty: String = DEFAULT_DIFFICULTY
## `docs/specs/scenarios.md` §1: "" is no scenario. Whether scenarios are unlocked
## is the profile's business, as a slot's is.
var scenario: String = ""


static func create(p_architecture: String = ArchitectureDef.DEFAULT_ID,
		p_directives: Array[String] = [], p_difficulty: String = DEFAULT_DIFFICULTY,
		p_scenario: String = "") -> RunSetup:
	var setup: RunSetup = RunSetup.new()
	setup.architecture = p_architecture
	setup.directives = p_directives.duplicate()
	setup.difficulty = p_difficulty
	setup.scenario = p_scenario
	return setup


## "" when the content knows the architecture, the difficulty, every directive and
## the scenario (if there is one), and no two directives share a slot; else
## `Command.FAIL_SETUP_INVALID`. Whether a slot is unlocked is the profile's
## business, not the simulation's (§1). A root without difficulties knows
## `standard` only.
func validate(db: ContentDB) -> String:
	if db.architecture(architecture) == null:
		return Command.FAIL_SETUP_INVALID
	if db.difficulty(difficulty) == null \
			and not (db.difficulties.is_empty() and difficulty == DifficultyDef.DEFAULT_ID):
		return Command.FAIL_SETUP_INVALID
	if not scenario.is_empty() and db.scenario(scenario) == null:
		return Command.FAIL_SETUP_INVALID
	var slots: Dictionary[String, bool] = {}
	for directive_id: String in directives:
		var directive: DirectiveDef = db.directive(directive_id)
		if directive == null or slots.has(directive.slot):
			return Command.FAIL_SETUP_INVALID
		slots[directive.slot] = true
	return ""


func duplicate_setup() -> RunSetup:
	return RunSetup.create(architecture, directives, difficulty, scenario)


func to_dict() -> Dictionary:
	return {
		"architecture": architecture,
		"directives": directives.duplicate(),
		"difficulty": difficulty,
		"scenario": scenario,
	}


## Null for a missing or ill-typed field. `scenario` alone may be missing — a
## setup written before S5.8 has none — but never of another type.
static func from_dict(d: Dictionary) -> RunSetup:
	if typeof(d.get("architecture")) != TYPE_STRING or typeof(d.get("difficulty")) != TYPE_STRING \
			or typeof(d.get("directives")) != TYPE_ARRAY:
		return null
	if d.has("scenario") and typeof(d["scenario"]) != TYPE_STRING:
		return null
	var directives: Array[String] = []
	for entry: Variant in d["directives"]:
		if typeof(entry) != TYPE_STRING:
			return null
		directives.append(str(entry))
	return RunSetup.create(str(d["architecture"]), directives, str(d["difficulty"]),
		str(d.get("scenario", "")))
