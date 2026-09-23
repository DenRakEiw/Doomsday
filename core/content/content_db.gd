class_name ContentDB
extends RefCounted
## Everything a run is played from: regions, links, technology and balance, as
## typed definitions. Built by `ContentLoader` only, immutable afterwards, and
## shared by every `World` that runs on this content.

## Index 0 is "no region" and is null. `regions[i].index == i` for the rest, so
## every loop over regions is `for i: int in range(1, regions.size())`.
var regions: Array[RegionDef] = []
var region_index_by_id: Dictionary[String, int] = {}
## File order, which is the iteration order of the simulation.
var links: Array[LinkDef] = []
## Tech files in ascending file-name order, nodes in the order of their file.
var tech_nodes: Array[TechNodeDef] = []
var tech_by_id: Dictionary[String, TechNodeDef] = {}
## File order, which is the order the headline system checks them in.
var headlines: Array[HeadlineDef] = []
var headline_by_id: Dictionary[String, HeadlineDef] = {}
## The four asset kinds, in `AssetDef.KINDS` order.
var assets: Dictionary[String, AssetDef] = {}
## File order, which is the order the region panel lists them in.
var statuses: Array[StatusDef] = []
var status_by_id: Dictionary[String, StatusDef] = {}
## File order, which is the order the region panel and the picker list them in.
var abilities: Array[AbilityDef] = []
var ability_by_id: Dictionary[String, AbilityDef] = {}
## Every `events/*.json` in ascending file-name order, events in file order —
## the order the opening draw weighs them in (§10.4).
var events: Array[EventDef] = []
var event_by_id: Dictionary[String, EventDef] = {}
## The four containment tracks in `Faction.FACTION_IDS` order — the order the
## tick grows them in and the panel lists them in.
var factions: Array[FactionDef] = []
var faction_by_id: Dictionary[String, FactionDef] = {}
## Exclusive group id -> how many of its nodes may be owned (§11.1).
var groups: Dictionary[String, int] = {}
var balance: BalanceDef = null
## Σ `RegionDef.population`, as a float because every formula using it is one.
var population_total: float = 0.0
## SHA-256 over the parsed content. Whitespace and key order do not change it; a
## value does. A save carrying a different hash would not replay.
var content_hash: String = ""


## The region with this id, or null.
func region_by_id(id: String) -> RegionDef:
	if not region_index_by_id.has(id):
		return null
	return regions[region_index_by_id[id]]


## The technology node with this id, or null.
func tech(id: String) -> TechNodeDef:
	if not tech_by_id.has(id):
		return null
	return tech_by_id[id]


## The headline with this id, or null.
func headline(id: String) -> HeadlineDef:
	if not headline_by_id.has(id):
		return null
	return headline_by_id[id]


## The asset kind with this id, or null.
func asset(kind: String) -> AssetDef:
	if not assets.has(kind):
		return null
	return assets[kind]


## The status definition with this id, or null.
func status(id: String) -> StatusDef:
	if not status_by_id.has(id):
		return null
	return status_by_id[id]


## The ability definition with this id, or null.
func ability(id: String) -> AbilityDef:
	if not ability_by_id.has(id):
		return null
	return ability_by_id[id]


## The faction definition with this id, or null.
func faction(id: String) -> FactionDef:
	if not faction_by_id.has(id):
		return null
	return faction_by_id[id]


## The map event definition with this id, or null.
func event(id: String) -> EventDef:
	if not event_by_id.has(id):
		return null
	return event_by_id[id]
