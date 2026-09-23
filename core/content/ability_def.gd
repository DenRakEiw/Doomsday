class_name AbilityDef
extends RefCounted
## One verb the player has (`loop-mechanics.md` §9.1).
##
## An ability is bought as a technology node and then used again and again: it
## costs Compute, it has a cooldown, and it applies exactly one of three things —
## a status, a deployment, or a list of one-shot effects. Which of the three is
## `applies_kind`; the vocabulary stops there, because an ability the interface
## cannot describe in one row is not an ability.
##
## Levels come from the tree: `levels_from` names one node per level, in level
## order, and each of those nodes names this ability back (the validator checks
## both directions, so the data cannot lie).

const TARGET_REGION: String = "region"
const TARGET_GLOBAL: String = "global"
const TARGETS: Array[String] = ["region", "global"]

const APPLIES_STATUS: String = "status"
const APPLIES_DEPLOY: String = "deploy"
const APPLIES_EFFECTS: String = "effects"
## Exactly one of these is the `applies` block's single key.
const APPLIES_KINDS: Array[String] = ["status", "deploy", "effects"]

## The keys an `abilities.json` entry allows.
const KEYS: Array[String] = ["id", "target", "cost", "cooldown_days", "eligible", "applies",
	"levels_from", "level_cap"]
## The keys an `applies.deploy` block allows.
const DEPLOY_KEYS: Array[String] = ["kind", "count"]
## The root list of `abilities.json`.
const ROOT_KEY: String = "abilities"

var id: String
var target: String = TARGET_REGION
var cost: float = 0.0
var cooldown_days: int = 0
## Region target only; `Eligibility.none()` for a global ability.
var eligible: Eligibility = null
var applies_kind: String = APPLIES_STATUS
var applies_status: String = ""
var applies_deploy_kind: String = ""
var applies_deploy_count: int = 0
var applies_effects: Array[EffectDef] = []
## Node ids in level order; at least one.
var levels_from: Array[String] = []
## The highest status level this ability ever applies. 0 means "as many levels
## as `levels_from` has", which is what the validator then demands of the status.
var level_cap: int = 0


static func name_key(ability_id: String) -> String:
	return "ABILITY_%s_NAME" % ability_id.to_upper()


static func detail_key(ability_id: String) -> String:
	return "ABILITY_%s_DETAIL" % ability_id.to_upper()


## How many levels the tree can grant.
func max_level() -> int:
	return levels_from.size()


## The status level an ability level applies, honouring `level_cap`.
func status_level_for(level: int) -> int:
	if level_cap > 0:
		return mini(level, level_cap)
	return level


func targets_region() -> bool:
	return target == TARGET_REGION
