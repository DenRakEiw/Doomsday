extends GutTest
## S3.2 — the tech tree in a running session (spec m3-screens.md §3.1–§3.3).
##
## The whole session scene, because what is worth testing here is the wiring: a
## button that spends Compute, a setting that stops the clock, and costs that
## follow the escalation without anyone re-opening the modal.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
## The scripts of the three scene-specific nodes this test drives; they carry no
## `class_name`, so the type comes from the file.
const TechTree: GDScript = preload("res://ui/panels/tech_tree.gd")
const TechBoard: GDScript = preload("res://ui/panels/tech_board.gd")
const TechDetail: GDScript = preload("res://ui/panels/tech_detail.gd")
const SEED: int = 1
## A first Infiltration node: cheap, and it needs nothing.
const FIRST_NODE: String = "open_weights_leak"
## Command Network Presence needs Log Manipulation II and Distributed Redundancy
## II — both in other trees (§7.5.4).
const EXTERNAL_NODE: String = "command_network_presence"

var _session: Control = null
var _tree: TechTree = null
var _board: TechBoard = null
var _detail: TechDetail = null
var _reduced_motion: bool = false
var _tree_pauses: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_tree_pauses = Settings.tree_pauses
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_tree = _session.get_node("ModalLayer/ModalHost/TechTree")
	_board = _tree.get_node("%Board")
	_detail = _tree.get_node("%TechDetail")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Settings.set_tree_pauses(_tree_pauses)
	Game.stop_run()


## A player's run with an origin and Compute to spend.
func _start(compute: float = 100.0) -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.agent.compute += compute
	_tree.open()


func test_buying_through_the_modal_applies_the_command() -> void:
	_start()
	var events: Array[SimEvent] = []
	EventBus.sim_event.connect(func(event: SimEvent) -> void: events.append(event))
	var before: float = Game.sim.world.agent.compute
	var cost: float = Game.sim.node_cost(FIRST_NODE)

	_board.node_selected.emit(FIRST_NODE)
	assert_eq(_detail.shown_id(), FIRST_NODE, "the pane follows the selection")
	var buy: Button = _detail.get_node("%Buy") as Button
	assert_false(buy.disabled, "an affordable node can be bought")
	buy.emit_signal("pressed")

	assert_true(Game.sim.world.agent.owns(FIRST_NODE))
	assert_almost_eq(Game.sim.world.agent.compute, before - cost, 1e-6)
	assert_eq(_board.node_for(FIRST_NODE).state, TechNode.State.OWNED)
	var purchased: int = 0
	for event: SimEvent in events:
		if event.type == SimEvent.NODE_PURCHASED:
			purchased += 1
	assert_eq(purchased, 1, "and the bus heard about it")


func test_an_unaffordable_node_cannot_be_bought() -> void:
	_start(0.0)
	Game.sim.world.agent.compute = 0.0
	_tree.close()
	_tree.open()
	_board.node_selected.emit(FIRST_NODE)
	var buy: Button = _detail.get_node("%Buy") as Button
	assert_true(buy.disabled)
	assert_eq(_board.node_for(FIRST_NODE).state, TechNode.State.AVAILABLE)


func test_tree_pauses_by_setting() -> void:
	Settings.set_tree_pauses(true)
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.set_speed(2)
	_tree.open()
	assert_eq(Game.speed, 0, "the run waits while the tree is up")
	assert_true(Game.is_held())
	_tree.close()
	assert_eq(Game.speed, 2, "and goes back to the speed it was at")

	Settings.set_tree_pauses(false)
	Game.set_speed(1)
	_tree.open()
	assert_eq(Game.speed, 1, "with the setting off the world keeps turning")
	_tree.close()


func test_external_prerequisite_shows_glyph_and_row() -> void:
	_start()
	# Its one prerequisite inside the tab is owned, so the only thing left in its
	# way is the Evasion gate — which is what EXTERNAL means (§3.5).
	Game.sim.world.agent.owned_nodes.append("early_warning_intrusion")
	_tree.close()
	_tree.open()
	# The Capabilities tab, where Command Network Presence lives.
	_tree.get_node("%Tabs").get_child(1).emit_signal("pressed")
	var node: TechNode = _board.node_for(EXTERNAL_NODE)
	assert_not_null(node)
	assert_eq(node.state, TechNode.State.LOCKED)
	assert_true(node.has_external_prerequisite, "both gates are in another tree")
	assert_eq(node.glyph(), Glyphs.Glyph.EXTERNAL)

	_board.node_selected.emit(EXTERNAL_NODE)
	var rows: VBoxContainer = _detail.get_node("%Requires") as VBoxContainer
	assert_eq(rows.get_child_count(), 3, "every prerequisite gets a row")
	var elsewhere: String = tr("UI_TREE_IN_TAB").format(
		{"tab": tr("UI_TREE_TAB_EVASION")})
	var found: bool = false
	for row: Node in rows.get_children():
		for child: Node in row.get_children():
			var label: Label = child as Label
			if label != null and label.text == elsewhere:
				found = true
	assert_true(found, "the pane says which tab to look in")


func test_costs_follow_escalation_every_tick() -> void:
	_start()
	var other: String = "consumer_devices"
	var before: float = Game.sim.node_cost(other)
	_board.node_selected.emit(FIRST_NODE)
	(_detail.get_node("%Buy") as Button).emit_signal("pressed")
	Game.advance(1)
	var after: float = Game.sim.node_cost(other)
	assert_almost_eq(after, before + Game.db.balance.compute_cost_step, 1e-6)
	var node: TechNode = _board.node_for(other)
	assert_string_contains(node.accessibility_name,
		Format.number(after, Format.Kind.COMPUTE))


func test_the_tab_chip_counts_what_is_owned() -> void:
	_start()
	var chip: Chip = _tree.tab_chip(0)
	var total: int = 0
	for definition: TechNodeDef in Game.db.tech_nodes:
		if definition.tree == TechNodeDef.TREE_INFILTRATION:
			total += 1
	assert_string_contains(_chip_text(chip), str(total))
	_board.node_selected.emit(FIRST_NODE)
	(_detail.get_node("%Buy") as Button).emit_signal("pressed")
	assert_string_contains(_chip_text(chip), "1 /")


func _chip_text(chip: Chip) -> String:
	for child: Node in chip.get_children():
		var label: Label = child as Label
		if label != null:
			return label.text
	return ""


func test_escape_closes_the_tree_and_releases_the_hold() -> void:
	Settings.set_tree_pauses(true)
	_start()
	assert_true(_tree.is_open())
	_tree.on_escape()
	assert_false(_tree.is_open())
	assert_false(Game.is_held())
