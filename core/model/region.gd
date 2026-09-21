class_name Region
extends RefCounted
## The mutable state of one region. Its definition is in `def` and never changes.

var def: RegionDef
## Share of the region's hardware the agent runs on, [0, 1].
var penetration: float = 0.0
## Hold over the region's infrastructure, [0, 1].
var control: float = 0.0
## People. Starts at `def.population`; `alive + deaths` stays that sum.
var alive: float = 0.0
var deaths: float = 0.0
## Day of the first infection; -1 while the region is clean.
var seeded_day: int = -1
## Starts at `def.air_gapped`; a region can lose the property later.
var air_gapped: bool = false
## Depopulated: no hardware, no people, inert for good (core.md §7.4).
var dark: bool = false


static func create(definition: RegionDef) -> Region:
	var region: Region = Region.new()
	region.def = definition
	region.alive = float(definition.population)
	region.air_gapped = definition.air_gapped
	return region
