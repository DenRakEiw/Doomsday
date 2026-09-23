class_name FactionTermDef
extends RefCounted
## One term of a faction's pressure: a pure read of the world times a weight
## (`opposition.md` §5.3). A faction's pressure is `1 + Σ weight × value` over
## its terms, so what a faction reacts to is data and the panel shows the same
## list the tick adds up.

const SOURCE_FOOTPRINT: String = "footprint"
const SOURCE_HARM: String = "harm"
const SOURCE_SHARE: String = "share"
const SOURCE_DEATHS_SHARE: String = "deaths_share"
const SOURCE_SEEDED_SHARE: String = "seeded_share"
const SOURCE_OWNED_NODES: String = "owned_nodes"
const SOURCE_WATCHED_STATUSES: String = "watched_statuses"
const SOURCE_ASSETS: String = "assets"
const SOURCES: Array[String] = ["footprint", "harm", "share", "deaths_share", "seeded_share",
	"owned_nodes", "watched_statuses", "assets"]
## The keys a term allows; `tree` and `kind` only with their source.
const KEYS: Array[String] = ["source", "weight", "tree", "kind"]

var source: String
## ≥ 0.
var weight: float = 0.0
## `owned_nodes` only: a tree id.
var tree: String = ""
## `assets` only: an asset kind.
var kind: String = ""


## The read itself, ≥ 0 (§5.3).
func value(world: World, db: ContentDB, faction_id: String) -> float:
	match source:
		SOURCE_FOOTPRINT:
			return world.modifiers.footprint_for(faction_id)
		SOURCE_HARM:
			return _harm(world)
		SOURCE_SHARE:
			return world.infected_share(db)
		SOURCE_DEATHS_SHARE:
			if db.population_total <= 0.0:
				return 0.0
			return world.deaths_total() / db.population_total
		SOURCE_SEEDED_SHARE:
			var regions: int = world.regions.size() - 1
			if regions <= 0:
				return 0.0
			return float(world.seeded_count()) / float(regions)
		SOURCE_OWNED_NODES:
			var count: int = 0
			for node_id: String in world.agent.owned_nodes:
				var node: TechNodeDef = db.tech(node_id)
				if node != null and node.tree == tree:
					count += 1
			return float(count)
		SOURCE_WATCHED_STATUSES:
			return float(_watched_statuses(world, db, faction_id))
		SOURCE_ASSETS:
			return float(world.asset_total(kind))
	push_error("unknown faction term source \"%s\"" % source)
	return 0.0


func contribution(world: World, db: ContentDB, faction_id: String) -> float:
	return weight * value(world, db, faction_id)


## The alive-weighted mean of the scoped Harm over the regions that are not
## dark: D4.0 moved Harm onto regional statuses, so the unscoped stat of a
## Cyber run reads 0.
static func _harm(world: World) -> float:
	var weighted: float = 0.0
	var alive: float = 0.0
	for i: int in range(1, world.regions.size()):
		var region: Region = world.regions[i]
		if region.dark or region.alive <= 0.0:
			continue
		weighted += world.modifiers.value(SOURCE_HARM, region.def) * region.alive
		alive += region.alive
	if alive <= 0.0:
		return 0.0
	return weighted / alive


## The player's own statuses this faction watches: a Blackout counts for every
## faction it names, a world status for none.
static func _watched_statuses(world: World, db: ContentDB, faction_id: String) -> int:
	var count: int = 0
	for status: Status in world.statuses:
		var definition: StatusDef = db.status(status.id)
		if definition == null or definition.origin != StatusDef.ORIGIN_PLAYER:
			continue
		if definition.watched_by.has(faction_id):
			count += 1
	return count
