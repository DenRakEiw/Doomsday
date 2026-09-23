class_name Pulse
extends RefCounted
## A timed Footprint with no status behind it (`loop-mechanics.md` §3.2).
##
## `footprint_pulse` is "somebody noticed, and they will stop talking about it
## in a week": there is nothing for the map to draw and nothing for a region
## panel to list, so it is its own small record rather than a status with a
## synthetic definition (§20 item 4).
##
## `StatusSystem.tick` expires it, like everything else with a day on it.

## The prefix of the modifier source id a pulse is active under.
const SOURCE_PREFIX: String = "pulse"

## How much Footprint it adds while it runs.
var value: float = 0.0
## Ends on the tick whose day is at or past this.
var until_day: int = 0
## The factions that notice it. Read by S4.4's per-faction Footprint.
var watched_by: Array[String] = []
## `World.next_pulse_id` at creation; the source id is built from it.
var index: int = 0


static func source_id_for(pulse_index: int) -> String:
	return "%s:%d" % [SOURCE_PREFIX, pulse_index]


func source_id() -> String:
	return source_id_for(index)


func days_left(day: int) -> int:
	return maxi(0, until_day - day)


## The save's row (§3.6); the value as bits, like every float in a save.
func to_dict() -> Dictionary:
	return {
		"index": index,
		"value": FloatBits.to_hex(value),
		"until_day": until_day,
		"watched_by": watched_by.duplicate(),
	}
