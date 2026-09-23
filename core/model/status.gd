class_name Status
extends RefCounted
## One status actually running, on a region or on the agent
## (`loop-mechanics.md` §3.2).
##
## `region == 0` means it is on the agent — global, and every regional modifier
## of it then acts everywhere at once (§7.3). A status is **exclusive per
## region**: applying one that already stands refreshes it rather than stacking
## a second (§7.2).
##
## `until_day == UNTIL_STANDING` is a standing status: it never expires on its
## own and is only ever ended by something that ends it (D4.4).

## The `until_day` of a standing status, and what `days_total` / `days_left`
## answer for one.
const UNTIL_STANDING: int = -1
const STANDING: int = -1

## Source prefixes, so that a source can be read back apart (§16.3.1).
const SOURCE_ABILITY: String = "ability"
const SOURCE_FACTION: String = "faction"
const SOURCE_EVENT: String = "event"
const SOURCE_EFFECT: String = "effect"
## The prefix of the modifier source id a running status is active under.
const SOURCE_PREFIX: String = "status"

var id: String
## 0 = on the agent.
var region: int = 0
## `"ability:<id>"` · `"faction:<id>"` · `"event:<def id>"` · `"effect"`.
var source: String = ""
## 1-based index into `StatusDef.levels`.
var level: int = 1
var started_day: int = 0
## Ends on the tick whose day is at or past this; `UNTIL_STANDING` never does.
var until_day: int = 0
## The answered option of the event that applied it; "" if none.
var option: String = ""
## Link ids this status closed, so that expiry reopens exactly those.
var closed_links: Array[String] = []


## The source id under which its modifiers are active. One per id and region, so
## that a refresh replaces in place rather than stacking.
static func source_id_for(status_id: String, region_index: int) -> String:
	return "%s:%s:%d" % [SOURCE_PREFIX, status_id, region_index]


## `"ability:<id>"` for an ability, and so on. The prefix is what the interface
## reads to decide a colour.
static func source_for(prefix: String, owner_id: String) -> String:
	return "%s:%s" % [prefix, owner_id]


## The faction a source names, or "" — a status applied by anything but a
## faction has none, whatever its definition's origin says (§16.3.1).
static func faction_of(source_text: String) -> String:
	var prefix: String = "%s:" % SOURCE_FACTION
	if not source_text.begins_with(prefix):
		return ""
	return source_text.substr(prefix.length())


func source_id() -> String:
	return source_id_for(id, region)


## How many days it was granted; −1 for a standing status.
func days_total() -> int:
	if until_day == UNTIL_STANDING:
		return STANDING
	return until_day - started_day


## How many days are left on `day`; −1 for a standing status. Never negative:
## a status that is due is at 0 until the tick takes it away.
func days_left(day: int) -> int:
	if until_day == UNTIL_STANDING:
		return STANDING
	return maxi(0, until_day - day)


func is_standing() -> bool:
	return until_day == UNTIL_STANDING


## The faction behind it, or "" for the player's own.
func faction() -> String:
	return faction_of(source)


## The save's row (§3.6). `region` is written as an id by the caller, which is
## the one that knows the world.
func to_dict(region_id: String) -> Dictionary:
	return {
		"id": id,
		"region": region_id,
		"source": source,
		"level": level,
		"started_day": started_day,
		"until_day": until_day,
		"option": option,
		"closed_links": closed_links.duplicate(),
	}
