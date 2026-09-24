class_name EventOptionDef
extends RefCounted
## One answer to a map event (`loop-mechanics.md` §10.1).
##
## What it costs, what it needs (`requires`, §10.2), what it does at once
## (`effects`), what it may do on a roll (`chance`) and, on a chain step, what
## comes after it (`next`). A counter-move's option also says how the move's
## status lands: at which level, for how long, or not at all.

## The keys an option allows.
const KEYS: Array[String] = ["id", "cost", "requires", "effects", "chance", "flags",
	"status_level", "status_days", "skip_status", "next"]
## The keys of `requires` (§10.2), in the order `lock_reason` checks them.
const REQUIRES_KEYS: Array[String] = ["owned", "owned_any", "not_owned", "flag", "asset_min",
	"compute_min", "ability"]
## The keys of one `next` entry.
const NEXT_KEYS: Array[String] = ["step", "delay_days"]

## Lock reasons, each the tail of `UI_EVENT_LOCK_<REASON>` (§17.4).
const LOCK_NODE: String = "node"
const LOCK_NODE_ANY: String = "node_any"
const LOCK_NOT_OWNED: String = "not_owned"
const LOCK_FLAG: String = "flag"
const LOCK_ASSET: String = "asset"
const LOCK_COMPUTE: String = "compute"
const LOCK_ABILITY: String = "ability"
const LOCK_REASONS: Array[String] = ["node", "node_any", "not_owned", "flag", "asset",
	"compute", "ability"]

## The one word a `cost` may be instead of a number (emergent options only).
const COST_SUPPRESSION: String = "suppression"

var id: String
var cost: float = 0.0
## `"cost": "suppression"` (§3.1): the price is the run's escalating suppression
## cost, asked of `Simulation.option_cost`, and `cost` stays 0.
var cost_suppression: bool = false
## `requires.owned`: every one of these nodes.
var requires_owned: Array[String] = []
## `requires.owned_any`: at least one of these.
var requires_owned_any: Array[String] = []
## `requires.not_owned` (D4.4): none of these.
var requires_not_owned: Array[String] = []
## `requires.flag`: every one set — modifier, timed or story flag.
var requires_flag: Array[String] = []
## `requires.asset_min`: in the event's region.
var requires_asset_min: Dictionary[String, int] = {}
## `requires.compute_min`; below 0 when not given.
var requires_compute_min: float = -1.0
## `requires.ability`: unlocked at any level.
var requires_ability: String = ""
var effects: Array[EffectDef] = []
var chance: Array[EventChanceDef] = []
## Story flags set when this option is chosen.
var flags: Array[String] = []
## Counter-move: 0 = the open event's level, n = level n (D4.2).
var status_level: int = 0
## Counter-move: 0 = the level's days, n = n days instead (D4.2).
var status_days: int = 0
## Counter-move: the move's status is not applied.
var skip_status: bool = false
## Chain follow-ups: `{"step": event id, "delay_days": int}`.
var next: Array[Dictionary] = []


## True when the option names anything under `requires`.
func has_requirements() -> bool:
	return not requires_owned.is_empty() or not requires_owned_any.is_empty() \
		or not requires_not_owned.is_empty() or not requires_flag.is_empty() \
		or not requires_asset_min.is_empty() or requires_compute_min >= 0.0 \
		or not requires_ability.is_empty()


## Why the option cannot be chosen, or an empty dictionary when it can (§10.2):
## `{"reason": <LOCK_*>, …arguments}`. `region` is the open event's region; the
## compute a choice costs is not a lock — the command says that separately.
func lock_reason(sim: Simulation, region: int) -> Dictionary:
	for node_id: String in requires_owned:
		if not sim.world.agent.owns(node_id):
			return {"reason": LOCK_NODE, "node": node_id}
	if not requires_owned_any.is_empty():
		var any: bool = false
		for node_id: String in requires_owned_any:
			if sim.world.agent.owns(node_id):
				any = true
				break
		if not any:
			return {"reason": LOCK_NODE_ANY, "nodes": requires_owned_any.duplicate()}
	for node_id: String in requires_not_owned:
		if sim.world.agent.owns(node_id):
			return {"reason": LOCK_NOT_OWNED}
	for flag: String in requires_flag:
		if not sim.has_flag(flag):
			return {"reason": LOCK_FLAG, "flag": flag}
	for kind: String in requires_asset_min:
		var held: int = 0
		if region > 0 and region < sim.world.regions.size():
			held = sim.world.regions[region].asset_count(kind)
		if held < requires_asset_min[kind]:
			return {"reason": LOCK_ASSET, "kind": kind, "count": requires_asset_min[kind]}
	if requires_compute_min >= 0.0 and sim.world.agent.compute < requires_compute_min:
		return {"reason": LOCK_COMPUTE, "value": requires_compute_min}
	if not requires_ability.is_empty() and sim.ability_level(requires_ability) == 0:
		return {"reason": LOCK_ABILITY, "ability": requires_ability}
	return {}


## The string an event option's button carries.
static func text_key(event_id: String, option_id: String) -> String:
	return "EVENT_%s_OPT_%s" % [event_id.to_upper(), option_id.to_upper()]


## What the world says once the option was chosen.
static func result_key(event_id: String, option_id: String) -> String:
	return "EVENT_%s_RESULT_%s" % [event_id.to_upper(), option_id.to_upper()]
