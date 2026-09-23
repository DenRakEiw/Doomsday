class_name StatusDef
extends RefCounted
## One timed condition a region or the agent can be under
## (`loop-mechanics.md` §7.1).
##
## A status is the one way anything in this game says *"and it keeps being true
## for a while"*: the player's abilities apply them, the world's counter-moves
## apply them, an event's option applies them. Nothing else is timed.
##
## Two kinds by `origin`: the player's own (drawn in `ACCENT`) and the world's
## (drawn in the faction's colour). The origin is what the content *means* —
## which colour a running status takes is read off the source it was applied
## with, because a chain can hand a world status to a region with no faction
## behind it (§16.3.1).

const ORIGIN_PLAYER: String = "player"
const ORIGIN_WORLD: String = "world"
const ORIGINS: Array[String] = ["player", "world"]

## The keys a `statuses.json` entry allows.
const KEYS: Array[String] = ["id", "origin", "watched_by", "levels", "border", "blocks",
	"cancellable"]
## The root list of `statuses.json`.
const ROOT_KEY: String = "statuses"
## `closes_links: ["all"]` closes every kind the region has.
const LINKS_ALL: String = "all"

var id: String
var origin: String = ORIGIN_PLAYER
## The factions that notice this status. Read by S4.4's per-faction Footprint.
var watched_by: Array[String] = []
## At least one; level *n* is `levels[n - 1]`.
var levels: Array[StatusLevelDef] = []
## Draw the region's border in the status colour (a Lockdown).
var border: bool = false
## Status ids the world's moves skip in this region (S4.5 reads it).
var blocks: Array[String] = []
## Reserved for the region panel's *Cancel* button; false in every status.
var cancellable: bool = false


static func name_key(status_id: String) -> String:
	return "STATUS_%s_NAME" % status_id.to_upper()


static func detail_key(status_id: String) -> String:
	return "STATUS_%s_DETAIL" % status_id.to_upper()


## The two or three capitals a status ring carries.
static func code_key(status_id: String) -> String:
	return "STATUS_%s_CODE" % status_id.to_upper()


## `level` clamped into the levels this status actually has. Content and a save
## can both name a level that is not there; nothing may index past the end.
func clamp_level(level: int) -> int:
	return clampi(level, 1, maxi(1, levels.size()))


## The level a 1-based number stands for, clamped. Null only for a definition
## with no levels at all, which validation refuses.
func level_at(level: int) -> StatusLevelDef:
	if levels.is_empty():
		return null
	return levels[clamp_level(level) - 1]


## The level's modifiers with the region scope injected (§7.3): a **regional**
## target acts in the region the status is in, a global one acts everywhere, and
## a status on the agent (`region == 0`) scopes nothing — that is how a global
## `spread_growth ×0.5` reaches every region at once.
##
## The definitions are never mutated: every scoped modifier is a fresh copy.
func scoped_modifiers(level: int, region: int) -> Array[ModifierDef]:
	var out: Array[ModifierDef] = []
	var lvl: StatusLevelDef = level_at(level)
	if lvl == null:
		return out
	for modifier: ModifierDef in lvl.modifiers:
		if region <= 0 or not ModifierDef.TARGETS_REGIONAL.has(modifier.target):
			out.append(modifier)
			continue
		var scoped: ModifierDef = ModifierDef.new()
		scoped.target = modifier.target
		scoped.op = modifier.op
		scoped.value = modifier.value
		scoped.scope_kind = ModifierDef.ScopeKind.REGION
		scoped.scope_region = region
		out.append(scoped)
	return out
