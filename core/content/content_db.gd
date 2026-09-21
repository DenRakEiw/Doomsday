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
