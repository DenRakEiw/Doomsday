class_name Command
extends RefCounted
## One player action. Every change to the world comes either from a system
## during a tick or from a command here — presentation never writes state.
##
## There is no queue: `Simulation.apply` runs between ticks and takes effect at
## once, so everything applied while the day is `d` is visible to every system of
## the tick that produces day `d + 1`.
##
## Commands carry **ids, not indices**, so a command log survives a re-indexed
## world. This class owns the failure reasons; each is also a localisation key,
## `CMD_FAIL_<REASON>` (`data/SCHEMA.md` §6).

const FAIL_GAME_OVER: String = "game_over"
const FAIL_ORIGIN_ALREADY_CHOSEN: String = "origin_already_chosen"
const FAIL_INVALID_REGION: String = "invalid_region"
const FAIL_REGION_NOT_ELIGIBLE: String = "region_not_eligible"
const FAIL_NO_ORIGIN: String = "no_origin"
const FAIL_UNKNOWN_NODE: String = "unknown_node"
const FAIL_ALREADY_OWNED: String = "already_owned"
const FAIL_MISSING_PREREQUISITE: String = "missing_prerequisite"
const FAIL_INSUFFICIENT_COMPUTE: String = "insufficient_compute"
const FAIL_UNKNOWN_ANOMALY: String = "unknown_anomaly"
const FAIL_DORMANCY_LOCKED: String = "dormancy_locked"
const FAIL_REGION_NOT_INFECTED: String = "region_not_infected"
const FAIL_DORMANCY_UNCHANGED: String = "dormancy_unchanged"
## The five checks a deploying node adds (`loop-mechanics.md` §11.3).
const FAIL_GROUP_FULL: String = "group_full"
const FAIL_EXCLUDED_BY: String = "excluded_by"
const FAIL_MISSING_ASSETS: String = "missing_assets"
const FAIL_SITE_REQUIRED: String = "site_required"
const FAIL_SITE_INELIGIBLE: String = "site_ineligible"
## The three checks an ability adds (`loop-mechanics.md` §9.3).
const FAIL_UNKNOWN_ABILITY: String = "unknown_ability"
const FAIL_ABILITY_LOCKED: String = "ability_locked"
const FAIL_ABILITY_COOLDOWN: String = "ability_cooldown"
## The three checks an event answer adds (`loop-mechanics.md` §10.5).
const FAIL_UNKNOWN_EVENT: String = "unknown_event"
const FAIL_UNKNOWN_OPTION: String = "unknown_option"
const FAIL_OPTION_LOCKED: String = "option_locked"

## Set by `Simulation.apply` when the command is accepted; -1 until then.
var day: int = -1


## The id this command serialises under, and the key `CommandCodec` reads.
func type_id() -> String:
	return ""


## The failure reason, or "" if the command would be accepted. Checks run in the
## order the spec lists them and the first failure is the reason.
@warning_ignore("unused_parameter")
func validate(sim: Simulation) -> String:
	return ""


## Runs only after `validate` returned "": everything it needs is known to be
## there. Appends what it caused to `events`.
@warning_ignore("unused_parameter")
func execute(sim: Simulation, events: Array[SimEvent]) -> void:
	pass


## `{"type", "day", …fields}`. Subclasses add their fields to this.
func to_dict() -> Dictionary:
	return {"type": type_id(), "day": day}
