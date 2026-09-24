class_name RunSetup
extends RefCounted
## What a run is before its origin (`replayability.md` §1): an architecture, a
## loadout of directives and a difficulty. Fixed for the run; in the save and in
## the replay header, so a replay rebuilds the same run.
##
## Directives and difficulty are carried from S5.1 on and read from S5.3 and S5.4.

const DEFAULT_DIFFICULTY: String = "standard"

var architecture: String = ArchitectureDef.DEFAULT_ID
## At most one per slot, only unlocked slots (the profile's check, S5.3).
var directives: Array[String] = []
var difficulty: String = DEFAULT_DIFFICULTY


static func create(p_architecture: String = ArchitectureDef.DEFAULT_ID,
		p_directives: Array[String] = [], p_difficulty: String = DEFAULT_DIFFICULTY) -> RunSetup:
	var setup: RunSetup = RunSetup.new()
	setup.architecture = p_architecture
	setup.directives = p_directives.duplicate()
	setup.difficulty = p_difficulty
	return setup


## "" when the content knows the architecture and every directive, and no two
## directives share a slot; else `Command.FAIL_SETUP_INVALID`. Whether a slot is
## unlocked is the profile's business, not the simulation's (§1). The difficulty
## check joins with its file (S5.4).
func validate(db: ContentDB) -> String:
	if db.architecture(architecture) == null:
		return Command.FAIL_SETUP_INVALID
	var slots: Dictionary[String, bool] = {}
	for directive_id: String in directives:
		var directive: DirectiveDef = db.directive(directive_id)
		if directive == null or slots.has(directive.slot):
			return Command.FAIL_SETUP_INVALID
		slots[directive.slot] = true
	return ""


func duplicate_setup() -> RunSetup:
	return RunSetup.create(architecture, directives, difficulty)


func to_dict() -> Dictionary:
	return {
		"architecture": architecture,
		"directives": directives.duplicate(),
		"difficulty": difficulty,
	}


## Null for a missing or ill-typed field.
static func from_dict(d: Dictionary) -> RunSetup:
	if typeof(d.get("architecture")) != TYPE_STRING or typeof(d.get("difficulty")) != TYPE_STRING \
			or typeof(d.get("directives")) != TYPE_ARRAY:
		return null
	var directives: Array[String] = []
	for entry: Variant in d["directives"]:
		if typeof(entry) != TYPE_STRING:
			return null
		directives.append(str(entry))
	return RunSetup.create(str(d["architecture"]), directives, str(d["difficulty"]))
