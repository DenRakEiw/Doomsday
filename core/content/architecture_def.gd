class_name ArchitectureDef
extends RefCounted
## What the agent is (`replayability.md` §2): a modifier set, a start, and at
## most one hook.
##
## A hook is a named rule rewrite from a closed list, each read in exactly one
## system. Content never adds a hook; a new hook is a spec change.

const HOOK_DRIFT: String = "drift"
const HOOK_NO_NETWORK: String = "no_network"
const HOOK_LABS_FROM_DAY_ONE: String = "labs_from_day_one"
const HOOK_ESCALATION: String = "escalation"
const HOOK_DISTRIBUTED: String = "distributed"
## §2.2 minus `cost_by_control`, which is a difficulty's.
const HOOKS: Array[String] = ["drift", "no_network", "labs_from_day_one", "escalation",
	"distributed"]

## The architecture a run is when nothing else is said (§1): the tutorial default,
## and what a v2 save and a content root without `architectures.json` are.
const DEFAULT_ID: String = "language_model"

## The keys an `architectures.json` entry allows.
const KEYS: Array[String] = ["id", "unlock", "modifiers", "start", "abilities", "hook"]
const START_KEYS: Array[String] = ["owned", "assets", "seed_top_hardware", "effects"]
## §8.1: `{}` or exactly one of these.
const UNLOCK_KEYS: Array[String] = ["runs_completed", "wins", "wins_by_outcome"]
## The root list of `architectures.json`.
const ROOT_KEY: String = "architectures"

var id: String
## The profile's business (S5.3); the simulation never reads it.
var unlock: Dictionary = {}
var modifiers: Array[ModifierDef] = []
## Nodes owned from the origin on, as if bought (§8.1).
var start_owned: Array[String] = []
## Asset kind → count, placed in the origin.
var start_assets: Dictionary[String, int] = {}
## How many regions besides the origin are seeded at the start, by hardware.
var start_seed_top_hardware: int = 0
## One-shot effects run in the origin once it is chosen.
var start_effects: Array[EffectDef] = []
## Abilities the architecture itself grants, at level 1 (§2.4).
var abilities: Array[String] = []
var hook: String = ""


## The architecture a root without the file plays as: no modifiers, no start.
static func default_def() -> ArchitectureDef:
	var def: ArchitectureDef = ArchitectureDef.new()
	def.id = DEFAULT_ID
	return def


static func name_key(architecture_id: String) -> String:
	return "ARCH_%s_NAME" % architecture_id.to_upper()
