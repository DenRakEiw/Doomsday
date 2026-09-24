class_name DifficultyDef
extends RefCounted
## One difficulty tier (`replayability.md` §5): a modifier set, a head start in
## Compute, and at the top the one hook a tier may carry.

## §2.2: every node costs more the more of the world the agent controls.
const HOOK_COST_BY_CONTROL: String = "cost_by_control"
const HOOKS: Array[String] = ["", "cost_by_control"]
## The tier a run is when nothing else is said, and what a root without the file
## plays at.
const DEFAULT_ID: String = "standard"

const KEYS: Array[String] = ["id", "start_compute", "hook", "modifiers"]
const ROOT_KEY: String = "tiers"
const DEFAULT_KEY: String = "default"

var id: String
var start_compute: float = 0.0
var hook: String = ""
var modifiers: Array[ModifierDef] = []


static func name_key(difficulty_id: String) -> String:
	return "DIFFICULTY_%s_NAME" % difficulty_id.to_upper()
