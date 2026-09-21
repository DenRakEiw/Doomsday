extends GutTest
## S1.7 — the real world, checked against `docs/specs/world.md` §7.
##
## Thresholds rather than exact counts wherever the design may still be retuned,
## so that changing a tier does not break a test that is not about tiers. The
## numbers that *are* exact are the ones that catch a wrong join: the population
## sums, and the shape of the index space.

const WORLD_ROOT: String = "res://data"
const STRINGS: String = "res://data/loc/strings.csv"
const REGION_COUNT: int = 61
const LAND_LINKS: int = 82
const EXTRA_LINKS: int = 69

## The eleven island regions of world.md §3.1 — reachable only by authored links.
const ISLANDS: Array[String] = ["caribbean", "greenland", "britain_ireland", "iceland",
	"sri_lanka", "japan", "taiwan", "philippines", "madagascar", "australia", "new_zealand"]

## Vector → the attribute it favours (world.md §3.4). Open Weights Leak is the
## one that reads two attributes and is checked on its own.
const VECTORS: Dictionary[String, String] = {
	"Cloud Federation": "connectivity",
	"Supply Chain Firmware": "manufacturing",
	"Consumer Devices": "population",
	"Industrial Control": "industry",
	"Research Networks": "research",
	"Satellite Uplink": "isolation",
}
const STRONG_TIER: int = 3
const MIN_STRONG: int = 3
## Every vector but Supply Chain Firmware, which is deliberately concentrated.
const MIN_CONTINENTS: int = 3

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func _db_or_skip() -> ContentDB:
	return _db


func test_the_world_loads_with_no_errors() -> void:
	var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
	assert_true(result.ok(), result.error_text())
	assert_eq(result.db.regions.size(), REGION_COUNT + 1, "61 regions plus the null at index 0")
	assert_eq(result.db.links.size(), LAND_LINKS + EXTRA_LINKS)


func test_the_indices_are_the_csv_row_order() -> void:
	var db: ContentDB = _db_or_skip()
	for i: int in range(1, db.regions.size()):
		assert_eq(db.regions[i].index, i)
	assert_eq(db.regions[1].id, "usa", "the first row of region_attributes.csv")
	assert_eq(db.regions[REGION_COUNT].index, REGION_COUNT)


func test_land_links_come_first_then_the_authored_ones() -> void:
	var db: ContentDB = _db_or_skip()
	var land: int = 0
	for link: LinkDef in db.links:
		if link.kind != LinkDef.KIND_LAND:
			break
		land += 1
	assert_eq(land, LAND_LINKS, "the file order is the simulation's iteration order")


func test_every_link_kind_is_represented() -> void:
	var db: ContentDB = _db_or_skip()
	var counts: Dictionary[String, int] = {}
	for kind: String in LinkDef.KINDS:
		counts[kind] = 0
	for link: LinkDef in db.links:
		counts[link.kind] += 1
	assert_eq(counts["land"], LAND_LINKS)
	assert_eq(counts["sea"], 37)
	assert_eq(counts["air"], 22)
	assert_eq(counts["network"], 10)


func test_the_link_graph_is_connected() -> void:
	var db: ContentDB = _db_or_skip()
	var neighbours: Array[PackedInt32Array] = _neighbours(db)
	var seen: Dictionary[int, bool] = {1: true}
	var queue: Array[int] = [1]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for next: int in neighbours[current]:
			if seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	assert_eq(seen.size(), REGION_COUNT, "every region has to be reachable from every other")


func test_every_region_has_at_least_two_neighbours() -> void:
	var db: ContentDB = _db_or_skip()
	var neighbours: Array[PackedInt32Array] = _neighbours(db)
	var lonely: Array[String] = []
	for i: int in range(1, db.regions.size()):
		if neighbours[i].size() < 2:
			lonely.append(db.regions[i].id)
	assert_eq(lonely.size(), 0, str(lonely))


func test_exactly_the_eleven_islands_have_no_land_link() -> void:
	var db: ContentDB = _db_or_skip()
	var landlocked: Dictionary[int, bool] = {}
	for link: LinkDef in db.links:
		if link.kind != LinkDef.KIND_LAND:
			continue
		landlocked[link.a] = true
		landlocked[link.b] = true
	var islands: Array[String] = []
	for i: int in range(1, db.regions.size()):
		if not landlocked.has(i):
			islands.append(db.regions[i].id)
	islands.sort()
	var expected: Array[String] = ISLANDS.duplicate()
	expected.sort()
	assert_eq(islands, expected)


func test_north_korea_is_the_only_air_gapped_region() -> void:
	var db: ContentDB = _db_or_skip()
	var gapped: Array[String] = []
	for i: int in range(1, db.regions.size()):
		if db.regions[i].air_gapped:
			gapped.append(db.regions[i].id)
	var expected: Array[String] = ["north_korea"]
	assert_eq(gapped, expected)


func test_the_population_sums_are_the_natural_earth_ones() -> void:
	var db: ContentDB = _db_or_skip()
	# Exact, because these catch a wrong join or a population moved with an
	# override — which the overrides deliberately do not do.
	assert_eq(int(db.population_total), 7676945548)
	assert_eq(db.region_by_id("usa").population, 328239523)
	assert_eq(db.region_by_id("pacific_islands").population, 12147405)
	assert_eq(db.region_by_id("caribbean").population, 42851759)


func test_every_infiltration_vector_has_somewhere_to_start() -> void:
	var db: ContentDB = _db_or_skip()
	for vector: String in VECTORS:
		var attribute: String = VECTORS[vector]
		var strong: Array[String] = []
		var continents: Dictionary[String, bool] = {}
		for i: int in range(1, db.regions.size()):
			var region: RegionDef = db.regions[i]
			if region.attr(attribute) < STRONG_TIER:
				continue
			strong.append(region.id)
			continents[region.continent] = true
		assert_gte(strong.size(), MIN_STRONG, "%s: %s" % [vector, strong])
		var floor_continents: int = 2 if vector == "Supply Chain Firmware" else MIN_CONTINENTS
		assert_gte(continents.size(), floor_continents, "%s spans %s" % [vector, continents.keys()])


func test_an_open_weights_leak_has_somewhere_to_land() -> void:
	var db: ContentDB = _db_or_skip()
	# A leak needs low regulation *and* hardware to land on.
	var strong: Array[String] = []
	var continents: Dictionary[String, bool] = {}
	for i: int in range(1, db.regions.size()):
		var region: RegionDef = db.regions[i]
		if region.attr("regulation") > 1 or region.attr("compute") < 1:
			continue
		strong.append(region.id)
		continents[region.continent] = true
	assert_gte(strong.size(), MIN_STRONG, str(strong))
	assert_gte(continents.size(), MIN_CONTINENTS, str(continents.keys()))


func test_every_region_and_continent_has_a_name_in_both_languages() -> void:
	var db: ContentDB = _db_or_skip()
	var strings: Dictionary[String, PackedStringArray] = _strings()
	var missing: Array[String] = []
	var continents: Dictionary[String, bool] = {}
	for i: int in range(1, db.regions.size()):
		continents[db.regions[i].continent] = true
		_require_key(strings, "REGION_%s" % db.regions[i].id.to_upper(), missing)
	for continent: String in continents:
		_require_key(strings, "CONTINENT_%s" % continent.to_upper(), missing)
	assert_eq(missing.size(), 0, str(missing))


func _require_key(strings: Dictionary[String, PackedStringArray], key: String,
		missing: Array[String]) -> void:
	if not strings.has(key):
		missing.append("%s: no row" % key)
		return
	var row: PackedStringArray = strings[key]
	if row.size() < 2 or row[0].strip_edges().is_empty() or row[1].strip_edges().is_empty():
		missing.append("%s: %s" % [key, row])


## key → [en, de], read straight from the file: Godot imports the CSV as
## translations, and a test wants the source rows.
func _strings() -> Dictionary[String, PackedStringArray]:
	var out: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	assert_not_null(file, "cannot open %s" % STRINGS)
	var header: PackedStringArray = file.get_csv_line()
	assert_eq(header[0], "keys")
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		out[row[0]] = PackedStringArray([row[1], row[2]])
	return out


func _neighbours(db: ContentDB) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	out.resize(db.regions.size())
	for i: int in db.regions.size():
		out[i] = PackedInt32Array()
	for link: LinkDef in db.links:
		if not out[link.a].has(link.b):
			out[link.a].append(link.b)
		if not out[link.b].has(link.a):
			out[link.b].append(link.a)
	return out
