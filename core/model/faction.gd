class_name Faction
extends RefCounted
## One containment track. M1 has exactly one, `unified`; S4.1 adds the other
## three without changing anything here.

var id: String
## [0, 1]; at 1 the run is lost.
var containment: float = 0.0


static func create(id: String) -> Faction:
	var faction: Faction = Faction.new()
	faction.id = id
	return faction
