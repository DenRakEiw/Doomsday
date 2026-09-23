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
## Held rather than active: the agent is there and frozen, and the region is out
## of the infected share (`tech-trees.md` §6.3). Waking resumes everything.
var dormant: bool = false
## Asset kind → count; an absent kind is 0. Written through `World.set_assets`
## only, which keeps the modifier stack's mirror in step (`loop-mechanics.md`
## §6.3).
var assets: Dictionary[String, int] = {}
## Societal Function: how well the place still runs. Saved from v2 on; nothing
## reads it before S4.5 (D4.2 §3.3).
var society: float = 0.0


static func create(definition: RegionDef) -> Region:
	var region: Region = Region.new()
	region.def = definition
	region.alive = float(definition.population)
	region.air_gapped = definition.air_gapped
	return region


## How many assets of a kind stand here; 0 for a kind that is not held.
func asset_count(kind: String) -> int:
	return int(assets.get(kind, 0))


## Whether anything of the agent's stands here at all.
func has_assets() -> bool:
	for kind: String in assets:
		if assets[kind] > 0:
			return true
	return false
