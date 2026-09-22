class_name Faction
extends RefCounted
## One containment track. M1 has exactly one, `unified`; S4.1 adds the other
## three without changing anything here.

## Every faction id the content may name — `watched_by` is validated against
## this list. Only `World.FACTION_UNIFIED` is a live track until S4.1.
const ID_AI_LABS: String = "ai_labs"
const ID_GOVERNMENTS: String = "governments"
const ID_SECURITY_RESEARCHERS: String = "security_researchers"
const ID_PUBLIC_SENTIMENT: String = "public_sentiment"
const FACTION_IDS: Array[String] = ["ai_labs", "governments", "security_researchers",
	"public_sentiment"]

var id: String
## [0, 1]; at 1 the run is lost.
var containment: float = 0.0


static func create(id: String) -> Faction:
	var faction: Faction = Faction.new()
	faction.id = id
	return faction
