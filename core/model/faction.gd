class_name Faction
extends RefCounted
## One containment track, one per entry of `factions.json` (opposition.md §3.1).
## What the faction reacts to and how it moves is its `FactionDef`.

## Every faction id the content may name, in the order the world tracks them —
## `factions.json` must list them in exactly this order.
const ID_AI_LABS: String = "ai_labs"
const ID_GOVERNMENTS: String = "governments"
const ID_SECURITY_RESEARCHERS: String = "security_researchers"
const ID_PUBLIC_SENTIMENT: String = "public_sentiment"
const FACTION_IDS: Array[String] = ["ai_labs", "governments", "security_researchers",
	"public_sentiment"]

var id: String
## [0, 1]; at 1 the run is lost.
var containment: float = 0.0
## The counter-move schedule of D4.2, saved from v2 on so that S4.5 needs no v3.
## `funding_reset` writes them from S4.4 on; the schedule reads them from S4.5.
##
## The counter-move event in preparation (variants resolved), or "".
var preparing: String = ""
## The day the preparation fires; -1 while there is none.
var fire_day: int = -1
## The day the faction may prepare again.
var cooldown_until: int = 0


static func create(id: String) -> Faction:
	var faction: Faction = Faction.new()
	faction.id = id
	return faction
