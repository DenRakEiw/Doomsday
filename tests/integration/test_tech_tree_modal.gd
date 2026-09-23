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
	# The step is fractional since S4.1 and a price is a whole number, so the
	# rise is not the step itself: what the escalation promises is that every
	# purchase makes everything else dearer, and that the board says so.
	assert_gt(after, before, "a purchase raises every other price")
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

# ------------------------------------------- S4.1: the tree v3 rows and states


## The one deploying node the shipped content has at S4.1.
const DEPLOY_NODE: String = "logistics_fleets"
## The seven tier 1 Infiltration vectors share a group capped at two (§11.1).
const VECTOR_GROUP: String = "vectors"


## The text of every row in the detail pane's v3 block.
func _v3_lines() -> Array[String]:
	var out: Array[String] = []
	for child: Node in (_detail.get_node("%V3Rows") as Node).get_children():
		var label: Label = child as Label
		if label != null:
			out.append(label.text)
	return out


func _lines_contain(fragment: String) -> bool:
	for line: String in _v3_lines():
		if line.contains(fragment):
			return true
	return false


func test_the_detail_pane_says_what_a_node_deploys_and_where() -> void:
	_start()
	_tree.call("_select", DEPLOY_NODE)
	assert_true(_lines_contain(tr("ASSET_FLEET_NAME")), str(_v3_lines()))
	# The eligibility is listed as requirements, not as reasons (§16.6).
	assert_true(_lines_contain(tr("UI_ELIGIBLE_NEEDS_NOT_INFECTED")), str(_v3_lines()))
	assert_true(_lines_contain(tr("UI_ATTR_INDUSTRY")), str(_v3_lines()))
	# And the buy button asks for a site rather than for a purchase.
	var buy: Button = _detail.get_node("%Buy") as Button
	assert_string_contains(buy.text, Format.caps(tr("UI_TREE_BUY_PLACE").format(
		{"cost": Format.number(Game.sim.node_cost(DEPLOY_NODE), Format.Kind.COMPUTE)})))
	assert_false(buy.disabled, "everything but the site is fine")


func test_a_grouped_node_shows_the_group_and_closes_when_it_is_full() -> void:
	_start(200.0)
	_tree.call("_select", FIRST_NODE)
	var chip: Chip = _detail.get_node("%GroupChip") as Chip
	assert_true(chip.visible, "a grouped node says how much of its group is spoken for")

	# The cap is two: buy both, and the rest of the group reads as excluded.
	var bought: int = 0
	for node: TechNodeDef in Game.db.tech_nodes:
		if node.group != VECTOR_GROUP or bought >= Game.db.groups[VECTOR_GROUP]:
			continue
		assert_true(Game.apply(PurchaseNodeCommand.new(node.id)).ok, node.id)
		bought += 1
	var closed: TechNodeDef = null
	for node: TechNodeDef in Game.db.tech_nodes:
		if node.group == VECTOR_GROUP and not Game.sim.world.agent.owns(node.id):
			closed = node
			break
	assert_not_null(closed)
	assert_eq(TechNode.state_for(closed, Game.sim), TechNode.State.EXCLUDED)
	var args: Dictionary = TechNode.state_args(closed, Game.sim)
	assert_eq(args["max"], Game.db.groups[VECTOR_GROUP])
	assert_eq(args["owned"], bought)


## S4.9: a prerequisite row's state chip showed `{GROUP}: {OWNED} VON {MAX}` —
## the excluded state names its group, and the row passed no values.
func test_no_detail_text_is_left_unformatted_with_a_full_group() -> void:
	_start(200.0)
	var bought: int = 0
	for node: TechNodeDef in Game.db.tech_nodes:
		if node.group != VECTOR_GROUP or bought >= Game.db.groups[VECTOR_GROUP]:
			continue
		assert_true(Game.apply(PurchaseNodeCommand.new(node.id)).ok, node.id)
		bought += 1
	for node: TechNodeDef in Game.db.tech_nodes:
		_tree.call("_select", node.id)
		for label: Node in _detail.find_children("*", "Label", true, false):
			assert_false((label as Label).text.contains("{"),
				"%s: %s" % [node.id, (label as Label).text])


## S4.9 screenshots: on a phone the header came to 420 px, and the modal ran off
## both edges of a 400 px screen. German, at 100 % and at the largest scale.
func test_the_compact_header_fits_a_phone_in_german() -> void:
	var locale: String = Settings.locale
	var text_scale: float = Settings.text_scale
	Settings.set_locale("de")
	_start()
	var header: Control = _tree.get_node("%Header") as Control
	var room: float = 400.0 - float(UiTokens.GUTTER) * 2.0
	for scale: float in [1.0, UiTokens.TEXT_SCALES.back()]:
		Settings.set_text_scale(scale)
		await wait_process_frames(2)
		# A new theme makes the HUD re-read the (desktop-wide) test viewport and
		# put the tree back to its wide form, so the phone form is asked for after.
		_tree.set_compact(true)
		await wait_process_frames(2)
		assert_lt(header.get_combined_minimum_size().x, room, "at %s" % scale)
	Settings.set_text_scale(text_scale)
	Settings.set_locale(locale)
