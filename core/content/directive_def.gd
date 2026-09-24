class_name DirectiveDef
extends RefCounted
## One directive (`replayability.md` §4): a trade the player loads before a run —
## something up, something down, never a hook. A run takes at most one per slot.

## The keys a `directives.json` entry allows.
const KEYS: Array[String] = ["id", "slot", "modifiers"]
## The root lists of `directives.json`.
const ROOT_KEY: String = "directives"
const SLOTS_KEY: String = "slots"

var id: String
var slot: String
var modifiers: Array[ModifierDef] = []


static func name_key(directive_id: String) -> String:
	return "DIRECTIVE_%s_NAME" % directive_id.to_upper()


static func slot_key(slot_id: String) -> String:
	return "DIRECTIVE_SLOT_%s" % slot_id.to_upper()
