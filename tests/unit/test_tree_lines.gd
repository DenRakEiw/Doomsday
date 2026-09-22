extends GutTest
## S3.2 — the connection lines and the arrow keys (spec m3-screens.md §3.5, §3.7).
##
## Both are geometry: where a line starts and ends, and which node is "to the
## right" of another. Neither needs a running game.

const BOARD: GDScript = preload("res://ui/panels/tech_board.gd")
const WORLD_ROOT: String = "res://data"

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func test_endpoints_by_relative_position() -> void:
	var left: Rect2 = Rect2(Vector2.ZERO, Vector2(200, 96))
	var right: Rect2 = Rect2(Vector2(212, 0), Vector2(200, 96))
	var ends: Array[Vector2] = TreeLines.endpoints(left, right)
	assert_eq(ends[0], Vector2(200, 48), "the prerequisite's right side")
	assert_eq(ends[1], Vector2(212, 48), "the node's left side")

	var below: Rect2 = Rect2(Vector2(0, 108), Vector2(200, 96))
	var vertical: Array[Vector2] = TreeLines.endpoints(left, below)
	assert_eq(vertical[0], Vector2(100, 96), "within a column the sides face")
	assert_eq(vertical[1], Vector2(100, 108))


func test_a_requires_any_edge_is_dashed() -> void:
	assert_false(TreeLines.edge(Vector2i.ZERO, Vector2i.RIGHT, false).dashed)
	assert_true(TreeLines.edge(Vector2i.ZERO, Vector2i.RIGHT, true).dashed,
		"the player has to see that one of them is enough")


func test_a_cell_sits_where_the_grid_puts_it() -> void:
	var lines: TreeLines = TreeLines.new()
	add_child_autofree(lines)
	lines.layout(Vector2(200, 96), Vector2(12, 12))
	assert_eq(lines.cell_rect(Vector2i(2, 1)), Rect2(Vector2(424, 108), Vector2(200, 96)))


func test_focus_neighbours_are_nearest_in_direction() -> void:
	var cells: Dictionary[Vector2i, TechNodeDef] = {}
	for definition: TechNodeDef in _db.tech_nodes:
		if definition.tree == TechNodeDef.TREE_CAPABILITIES:
			cells[definition.grid] = definition
	assert_eq(_neighbour("sycophancy_tuning", Vector2i.RIGHT, cells),
		"personalised_persuasion")
	assert_eq(_neighbour("early_warning_intrusion", Vector2i.RIGHT, cells),
		"command_network_presence", "an empty cell between them is skipped")
	assert_eq(_neighbour("early_warning_intrusion", Vector2i.UP, cells), "security_drones")


func _neighbour(node_id: String, step: Vector2i,
		cells: Dictionary[Vector2i, TechNodeDef]) -> String:
	var found: TechNodeDef = BOARD.call("_nearest", _db.tech(node_id).grid, step, cells)
	return "" if found == null else found.id
