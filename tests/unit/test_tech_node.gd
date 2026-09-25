extends GutTest
## S3.2 — the tech node component (spec m3-screens.md §3.4).
##
## The interesting half is the one a screenshot would not catch: that a state is
## a theme variation rather than an override, and that the longest German name
## still fits the cell it was designed for.

const TECH_NODE: PackedScene = preload("res://ui/components/tech_node.tscn")
const WORLD_ROOT: String = "res://data"
## `TechNode.State` → the variation it must switch to.
const VARIATIONS: Array[String] = ["TechNodeLocked", "TechNode", "TechNodeAffordable",
	"TechNodeOwned"]
const LOCALES: Array[String] = ["en", "de"]

static var _db: ContentDB = null

var _root: Control = null
var _locale: String = ""


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	add_child_autofree(_root)


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _node(definition: TechNodeDef, state: TechNode.State, cost: float = 5.0) -> TechNode:
	var node: TechNode = TECH_NODE.instantiate()
	_root.add_child(node)
	node.bind(definition, cost, state, false)
	return node


func test_state_maps_to_variation() -> void:
	var definition: TechNodeDef = _db.tech("cloud_federation")
	for state: int in VARIATIONS.size():
		var node: TechNode = _node(definition, state as TechNode.State)
		assert_eq(String(node.theme_type_variation), VARIATIONS[state])
		var cost: Control = node.get_node("%NodeCost") as Control
		assert_eq(cost.visible, state != TechNode.State.OWNED,
			"an owned node shows no price")


func test_the_glyph_says_why_a_node_is_out_of_reach() -> void:
	var definition: TechNodeDef = _db.tech("cloud_federation")
	assert_eq(_node(definition, TechNode.State.OWNED).glyph(), Glyphs.Glyph.CHECK)
	assert_eq(_node(definition, TechNode.State.LOCKED).glyph(), Glyphs.Glyph.LOCK)
	assert_eq(_node(definition, TechNode.State.AVAILABLE).glyph(), -1)
	var external: TechNode = TECH_NODE.instantiate()
	_root.add_child(external)
	external.bind(definition, 5.0, TechNode.State.LOCKED, true)
	assert_eq(external.glyph(), Glyphs.Glyph.EXTERNAL)


func test_the_footer_shows_the_node_s_own_footprint() -> void:
	# Cloud Federation adds 2 unscoped Footprint; Supply Chain Firmware adds none.
	var loud: TechNode = _node(_db.tech("cloud_federation"), TechNode.State.AVAILABLE)
	var quiet: TechNode = _node(_db.tech("supply_chain_firmware"), TechNode.State.AVAILABLE)
	assert_true((loud.get_node("%Footprint") as Control).visible)
	assert_false((quiet.get_node("%Footprint") as Control).visible,
		"a node without one says nothing")


## §3.4 promises two lines and no ellipsis. It holds for every name in both
## languages at both cell sizes since G3 shortened the seven English ones that
## did not. The list is asserted exactly, so a name that overflows fails this
## test at once; a new entry belongs on the punch list, never a wider cell.
const KNOWN_OVERFLOW: Array[String] = []


func test_every_german_name_fits_two_lines() -> void:
	var too_long: Array[String] = []
	TranslationServer.set_locale("de")
	for cell: Vector2 in [UiTokens.TECH_CELL, UiTokens.TECH_CELL_COMPACT]:
		await _measure(cell, "de", too_long)
	assert_eq(too_long.size(), 0, str(too_long))


func test_every_english_name_fits_two_lines() -> void:
	var too_long: Array[String] = []
	TranslationServer.set_locale("en")
	for cell: Vector2 in [UiTokens.TECH_CELL, UiTokens.TECH_CELL_COMPACT]:
		await _measure(cell, "en", too_long)
	assert_eq(too_long, KNOWN_OVERFLOW)


## Lays every node out at `cell` and returns the ones whose name needs more
## lines than the node shows. The node is laid out for real: a wrapped line count
## is only true after the layout pass that produced it.
func _measure(cell: Vector2, locale: String, too_long: Array[String]) -> void:
	for definition: TechNodeDef in _db.tech_nodes:
		var node: TechNode = TECH_NODE.instantiate()
		node.custom_minimum_size = cell
		_root.add_child(node)
		node.bind(definition, 99.0, TechNode.State.AVAILABLE, false)
		node.size = cell
		await get_tree().process_frame
		var label: Label = node.get_node("%NodeName") as Label
		if label.get_line_count() > TechNode.NAME_LINES:
			too_long.append("%s %d %s" % [locale, int(cell.x), definition.id])
		_root.remove_child(node)
		node.queue_free()


## icons.md §7: the footer holds the icon, the cost, the footprint and the state
## glyph without overflowing the cell. At the full cell everything fits, and in
## the compact cell a node without a footprint; with one (Cloud Federation's
## +2) the compact footer has no room, and the icon — never the text — gives
## way (S6.4, DESIGN?).
func test_compact_footer_fits_icon() -> void:
	for cell: Vector2 in [UiTokens.TECH_CELL, UiTokens.TECH_CELL_COMPACT]:
		for id: String in ["supply_chain_firmware", "cloud_federation"]:
			var node: TechNode = TECH_NODE.instantiate()
			node.custom_minimum_size = cell
			_root.add_child(node)
			node.bind(_db.tech(id), 99.0, TechNode.State.LOCKED, true)
			node.size = cell
			await get_tree().process_frame
			var footer: Control = node.get_node("Content/Column/Footer") as Control
			var room: float = cell.x - float(UiTokens.SPACE_3) * 2.0
			var case: String = "%d %s" % [int(cell.x), id]
			assert_true(footer.get_combined_minimum_size().x <= room,
				"%s: the footer fits: %s" % [case, footer.get_combined_minimum_size()])
			if cell == UiTokens.TECH_CELL or id == "supply_chain_firmware":
				assert_true(node.shows_icon(), "%s: the icon has room" % case)
			_root.remove_child(node)
			node.queue_free()
