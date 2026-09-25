extends Control
## The grid of one tree tab and the lines between its nodes (spec m3-screens.md
## §3.2, §3.5).
##
## The board owns the cells: it builds them when a tab is shown, gives them their
## state every tick, and answers the arrow keys. What a node *means* is the
## modal's business — the board only knows what `Simulation` says about it.
##
## Scene-specific, so no `class_name`.

signal node_selected(node_id: String)
signal buy_requested(node_id: String)

const TECH_NODE: PackedScene = preload("res://ui/components/tech_node.tscn")
const VARIATION_GRID: StringName = &"TechGrid"
const VARIATION_GRID_COMPACT: StringName = &"TechGridCompact"
const SEPARATION_H: StringName = &"h_separation"
const SEPARATION_V: StringName = &"v_separation"

## The four ways an arrow key can go, as steps in cells.
const DIRECTIONS: Dictionary[StringName, Vector2i] = {
	&"focus_neighbor_left": Vector2i.LEFT,
	&"focus_neighbor_right": Vector2i.RIGHT,
	&"focus_neighbor_top": Vector2i.UP,
	&"focus_neighbor_bottom": Vector2i.DOWN,
}

@onready var _lines: TreeLines = %TreeLines
@onready var _grid: GridContainer = %Grid

## Node id → its button, for the tree that is shown.
var _nodes: Dictionary[String, TechNode] = {}
var _tree: String = ""
var _selected: String = ""
var _compact: bool = false
## Columns and rows of the tree that is shown.
var _span: Vector2i = Vector2i.ONE
## The run the board last read. It never writes to it.
var _sim: Simulation = null


func _ready() -> void:
	EventBus.text_scale_changed.connect(_on_text_scale_changed)


## Builds the cells of `tree`. Every tab rebuilds — 43 nodes at most, and pooling
## a grid this size would cost more than it saves.
func show_tree(tree: String, db: ContentDB, sim: Simulation) -> void:
	_tree = tree
	_selected = ""
	_nodes.clear()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var definitions: Array[TechNodeDef] = _tree_nodes(db)
	_span = span_of(definitions)
	_grid.columns = _span.x
	_fill(definitions, _span)
	_apply_geometry()
	refresh(sim)


## The costs and states of every shown node, as they are right now (§3.3).
func refresh(sim: Simulation) -> void:
	if sim == null:
		return
	_sim = sim
	for node_id: String in _nodes:
		var definition: TechNodeDef = sim.db.tech(node_id)
		var state: TechNode.State = TechNode.state_for(definition, sim)
		_nodes[node_id].bind(definition, sim.node_cost(node_id), state,
			_is_external(definition, sim, state))
	_draw_edges(sim)
	_mark_coach_vector(sim)


## first-run.md §3.3: the introduction's ring goes round the first vector the run
## can buy now — a node that ends the Boxed phase and is affordable.
func _mark_coach_vector(sim: Simulation) -> void:
	var marked: bool = false
	for node_id: String in _nodes:
		var node: TechNode = _nodes[node_id]
		if node.is_in_group(CoachRing.group(CoachRing.TARGET_VECTOR)):
			node.remove_from_group(CoachRing.group(CoachRing.TARGET_VECTOR))
		var definition: TechNodeDef = sim.db.tech(node_id)
		if marked or not definition.flags.has(ModifierDef.FLAG_BREAKOUT):
			continue
		if TechNode.state_for(definition, sim) == TechNode.State.AFFORDABLE:
			node.add_to_group(CoachRing.group(CoachRing.TARGET_VECTOR))
			marked = true


## Marks `node_id` as the selection; an empty id clears it. The lines follow:
## the selection is what tells the edges apart (§3.5).
func select(node_id: String) -> void:
	_selected = node_id
	for id: String in _nodes:
		_nodes[id].set_selected(id == node_id)
	if _sim != null:
		_draw_edges(_sim)


## plain-language.md §5.2 C2: the nodes an answer handed over wear a mark until
## the tree has been open once.
func set_marked(ids: Dictionary[String, bool]) -> void:
	for id: String in _nodes:
		_nodes[id].set_marked(ids.has(id))


func selected_id() -> String:
	return _selected


func node_for(node_id: String) -> TechNode:
	return _nodes.get(node_id, null)


func has_node_id(node_id: String) -> bool:
	return _nodes.has(node_id)


## Scrolls a node into view and gives it focus — what a jump from the detail
## pane's prerequisite row does (§3.6 item 6).
func reveal(node_id: String) -> void:
	var node: TechNode = node_for(node_id)
	if node == null:
		return
	node.grab_focus()


## The compact layout uses a smaller cell and a tighter gap (§3.2).
func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_resize_cells()


## Every cell of the grid — cards and the empty fillers between them — takes the
## current cell size, and the board and its lines follow.
func _resize_cells() -> void:
	for child: Node in _grid.get_children():
		(child as Control).custom_minimum_size = cell_size()
	if not _tree.is_empty():
		_apply_geometry()


func _on_text_scale_changed(_scale: float) -> void:
	_resize_cells()


## Whether the only thing in this node's way lives in another tree — then the
## board can say so with a glyph instead of drawing a line off the tab (§3.5).
static func _is_external(definition: TechNodeDef, sim: Simulation,
		state: TechNode.State) -> bool:
	if state != TechNode.State.LOCKED:
		return false
	var missing: Array[String] = _missing_prerequisites(definition, sim)
	if missing.is_empty():
		return false
	for node_id: String in missing:
		if sim.db.tech(node_id).tree == definition.tree:
			return false
	return true


## The prerequisites that are not satisfied: all of `requires` that are unowned,
## and the whole of `requires_any` when none of it is.
static func _missing_prerequisites(definition: TechNodeDef, sim: Simulation) -> Array[String]:
	var missing: Array[String] = []
	for node_id: String in definition.requires:
		if not sim.world.agent.owns(node_id):
			missing.append(node_id)
	if definition.requires_any.is_empty():
		return missing
	for node_id: String in definition.requires_any:
		if sim.world.agent.owns(node_id):
			return missing
	missing.append_array(definition.requires_any)
	return missing


func _tree_nodes(db: ContentDB) -> Array[TechNodeDef]:
	var out: Array[TechNodeDef] = []
	for definition: TechNodeDef in db.tech_nodes:
		if definition.tree == _tree:
			out.append(definition)
	return out


## Columns and rows the tree needs, from the data and never from a constant.
static func span_of(definitions: Array[TechNodeDef]) -> Vector2i:
	var span: Vector2i = Vector2i.ONE
	for definition: TechNodeDef in definitions:
		span.x = maxi(span.x, definition.grid.x + 1)
		span.y = maxi(span.y, definition.grid.y + 1)
	return span


## One child per cell in row-major order, which is also the tab order (§3.7).
func _fill(definitions: Array[TechNodeDef], span: Vector2i) -> void:
	var by_cell: Dictionary[Vector2i, TechNodeDef] = {}
	for definition: TechNodeDef in definitions:
		by_cell[definition.grid] = definition
	for row: int in span.y:
		for column: int in span.x:
			var cell: Vector2i = Vector2i(column, row)
			if by_cell.has(cell):
				_add_node(by_cell[cell])
				continue
			_grid.add_child(_empty_cell())
	_link_neighbours(by_cell)


func _add_node(definition: TechNodeDef) -> void:
	var node: TechNode = TECH_NODE.instantiate()
	node.custom_minimum_size = cell_size()
	_grid.add_child(node)
	node.selected.connect(_on_node_selected)
	node.buy_requested.connect(_on_node_buy_requested)
	_nodes[definition.id] = node


func _empty_cell() -> Control:
	var filler: Control = Control.new()
	filler.custom_minimum_size = cell_size()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return filler


## A card grows with the type it carries: at 150 % the names ran into each other
## and an owned card pushed its footer out (S4.9). The gap stays.
func cell_size() -> Vector2:
	var base: Vector2 = UiTokens.TECH_CELL_COMPACT if _compact else UiTokens.TECH_CELL
	return (base * Settings.text_scale).round()


func gap() -> Vector2:
	var variation: StringName = VARIATION_GRID_COMPACT if _compact else VARIATION_GRID
	return Vector2(
		float(_grid.get_theme_constant(SEPARATION_H, variation)),
		float(_grid.get_theme_constant(SEPARATION_V, variation)))


func _apply_geometry() -> void:
	_grid.theme_type_variation = VARIATION_GRID_COMPACT if _compact else VARIATION_GRID
	var cell: Vector2 = cell_size()
	var step: Vector2 = cell + gap()
	var full: Vector2 = Vector2(float(_span.x), float(_span.y)) * step - gap()
	# The lines control is anchored to the board, so it follows the size the
	# grid asks for; setting it by hand fights the layout.
	custom_minimum_size = full
	_lines.layout(cell, gap())


## Godot's own focus neighbours, so the arrow keys need no input handler: the
## nearest node strictly in that direction, by Manhattan distance (§3.7).
func _link_neighbours(by_cell: Dictionary[Vector2i, TechNodeDef]) -> void:
	for cell: Vector2i in by_cell:
		var node: TechNode = _nodes[by_cell[cell].id]
		for property: StringName in DIRECTIONS:
			var target: TechNodeDef = _nearest(cell, DIRECTIONS[property], by_cell)
			if target == null:
				continue
			node.set(property, _nodes[target.id].get_path())


static func _nearest(from: Vector2i, step: Vector2i,
		by_cell: Dictionary[Vector2i, TechNodeDef]) -> TechNodeDef:
	var best: TechNodeDef = null
	var best_distance: int = 0
	for cell: Vector2i in by_cell:
		var delta: Vector2i = cell - from
		if not _is_towards(delta, step):
			continue
		var distance: int = absi(delta.x) + absi(delta.y)
		if best == null or distance < best_distance:
			best = by_cell[cell]
			best_distance = distance
	return best


## Strictly in the direction of `step`: along the row for left and right, along
## the column for up and down. An arrow key that moved diagonally would be a
## worse map of the grid than no move at all.
static func _is_towards(delta: Vector2i, step: Vector2i) -> bool:
	if step.x != 0:
		return delta.y == 0 and signi(delta.x) == step.x
	return delta.x == 0 and signi(delta.y) == step.y


func _draw_edges(sim: Simulation) -> void:
	var edges: Array[TreeLines.Edge] = []
	var rings: Array[Vector2i] = []
	for node_id: String in _nodes:
		var definition: TechNodeDef = sim.db.tech(node_id)
		_collect_edges(definition, definition.requires, false, sim, edges, rings)
		_collect_edges(definition, definition.requires_any, true, sim, edges, rings)
	_lines.set_edges(edges, rings)


func _collect_edges(definition: TechNodeDef, prerequisites: Array[String], dashed: bool,
		sim: Simulation, edges: Array[TreeLines.Edge], rings: Array[Vector2i]) -> void:
	for required: String in prerequisites:
		if not _nodes.has(required):
			continue
		var from: TechNodeDef = sim.db.tech(required)
		var edge: TreeLines.Edge = TreeLines.edge(from.grid, definition.grid, dashed)
		edge.from_owned = sim.world.agent.owns(required)
		edge.to_owned = sim.world.agent.owns(definition.id)
		edge.selected = _selected == definition.id or _selected == required
		edges.append(edge)
		if _selected == definition.id:
			rings.append(from.grid)


func _on_node_selected(node_id: String) -> void:
	node_selected.emit(node_id)


func _on_node_buy_requested(node_id: String) -> void:
	buy_requested.emit(node_id)
