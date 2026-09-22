extends GutTest
## S2.5 — the region panel against a running simulation (spec ui-foundation.md
## §5.6).
##
## A selection is a signal, not a method call: the panel opens on
## `region_selected` and closes on `region_selected(0)`, which is what the close
## button, `Escape` and a tap on the ocean all produce — `Escape` itself is the
## session's key and is tested in `test_session_keys.gd`.

const PANEL_SCENE: PackedScene = preload("res://ui/panels/region_panel.tscn")
## The shortest way to the `dormancy` flag (m3-screens §8.1): a vector, the node
## that keeps it alive, and Cold Storage on top.
const DORMANCY_CHAIN: Array[String] = ["consumer_devices", "edge_caching",
	"cold_storage_dormancy"]

const SEED: int = 1
## `greedy` starts in the USA, so by then there is presence, population loss and
## the odd anomaly to look at.
const WARMUP_DAYS: int = 120
const REGION_USA: String = "usa"

var _root: Control = null
var _panel: SlidePanel = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	# Without motion the panel is at its open position in the same frame.
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)
	_panel = PANEL_SCENE.instantiate() as SlidePanel
	_root.add_child(_panel)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _start(days: int = WARMUP_DAYS) -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(days)


func _index_of(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


func _select(region_id: String) -> int:
	var index: int = _index_of(region_id)
	EventBus.region_selected.emit(index)
	return index


func _node(unique: String) -> Node:
	return _panel.get_node("%" + unique)


func _text(unique: String) -> String:
	return (_node(unique) as Label).text


func test_a_selection_opens_the_panel_on_that_region() -> void:
	_start()
	_select(REGION_USA)
	assert_true(_panel.is_open)
	assert_eq(int(_panel.call("region_index")), _index_of(REGION_USA))
	assert_eq(_text("RegionName"), tr("REGION_USA"))
	assert_eq(_text("Continent"), tr("CONTINENT_NORTH_AMERICA"))


func test_the_panel_speaks_the_language_that_is_set() -> void:
	_start()
	_select(REGION_USA)
	TranslationServer.set_locale("de")
	_panel.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(_text("RegionName"), "Vereinigte Staaten")
	assert_eq(_text("ProfileTitle"), "Profil")


func test_deselecting_closes_the_panel() -> void:
	_start()
	_select(REGION_USA)
	EventBus.region_selected.emit(0)
	assert_false(_panel.is_open)
	assert_eq(int(_panel.call("region_index")), 0)


func test_the_close_button_clears_the_selection_for_everyone() -> void:
	_start()
	_select(REGION_USA)
	watch_signals(EventBus)
	var close: Button = _node("CloseButton") as Button
	close.emit_signal("pressed")
	# The map draws the outline, so closing has to reach it too (§7.4).
	assert_signal_emitted_with_parameters(EventBus, "region_selected", [0])
	assert_false(_panel.is_open)


func test_an_untouched_region_hides_the_presence_bars() -> void:
	_start(1)
	# Day 1: the bot has an origin and nothing else. North Korea is air-gapped
	# and is reached by nobody (world.md).
	_select("north_korea")
	assert_false((_node("Presence") as Control).visible,
		"nothing is there, so there is nothing to measure")


func test_a_seeded_region_shows_how_far_in_it_is() -> void:
	_start()
	var index: int = _select(REGION_USA)
	var region: Region = Game.sim.world.regions[index]
	assert_true((_node("Presence") as Control).visible)
	var bars: VBoxContainer = _node("Presence") as VBoxContainer
	var penetration: StatBar = bars.get_child(0) as StatBar
	assert_almost_eq(penetration.value(), region.penetration, 0.001)


func test_the_deaths_row_appears_only_once_somebody_has_died() -> void:
	_start(1)
	_select(REGION_USA)
	assert_false((_node("DeathsRow") as Control).visible, "nobody has died on day 1")
	Game.advance(400)
	assert_true(Game.sim.world.regions[_index_of(REGION_USA)].deaths >= 1.0,
		"the run did not get far enough to kill anybody")
	assert_true((_node("DeathsRow") as Control).visible)


func test_the_profile_shows_every_attribute_at_its_tier() -> void:
	_start(1)
	var index: int = _select(REGION_USA)
	var definition: RegionDef = Game.sim.world.regions[index].def
	var grid: GridContainer = _node("Profile") as GridContainer
	assert_eq(grid.get_child_count(), RegionDef.ATTRIBUTES.size() * 2,
		"a label and a row of pips per attribute")
	var pips: AttributePips = grid.get_child(1) as AttributePips
	assert_eq(pips.tier, definition.attr("compute"), "the first row is compute")


## A chip cannot wrap, so being dark is a short badge plus a caption (§5.6, G2).
func test_a_dark_region_says_in_words_what_dark_means() -> void:
	_start()
	var index: int = _index_of(REGION_USA)
	var detail: Label = _node("DarkDetail") as Label
	_select(REGION_USA)
	assert_false(detail.visible, "a region with people in it says nothing")

	Game.sim.world.regions[index].dark = true
	EventBus.region_selected.emit(0)
	_select(REGION_USA)

	assert_true(detail.visible)
	assert_eq(detail.text, tr("UI_REGION_STATE_DARK_DETAIL"))


## G2: at 400 px the pips stood at the far edge of the panel, away from the
## label they belong to.
func test_the_profile_grid_shrinks_to_the_width_it_needs() -> void:
	_start()
	_select(REGION_USA)
	await get_tree().process_frame
	await get_tree().process_frame
	var grid: GridContainer = _node("Profile") as GridContainer
	assert_eq(grid.size_flags_horizontal, int(Control.SIZE_SHRINK_BEGIN))
	assert_almost_eq(grid.size.x, grid.get_combined_minimum_size().x, 1.0,
		"the pips sit beside the longest label, not at the panel's edge")


func test_a_link_row_counts_the_links_of_its_kind() -> void:
	_start(1)
	var index: int = _select(REGION_USA)
	var expected: int = 0
	for link: Link in Game.sim.world.links:
		if link.def.kind == LinkDef.KIND_LAND and (link.def.a == index or link.def.b == index):
			expected += 1
	var rows: VBoxContainer = _node("Links") as VBoxContainer
	var land: Label = rows.get_child(0) as Label
	assert_true(land.visible, "the USA has land links")
	assert_eq(land.text, "Land: %d" % expected)


func test_an_anomaly_can_be_collected_from_the_panel() -> void:
	_start(1)
	# Run until an anomaly exists somewhere, then select that region.
	var index: int = 0
	for i: int in 400:
		Game.advance(1)
		if not Game.sim.world.anomalies.is_empty():
			index = Game.sim.world.anomalies[0].region
			break
	assert_gt(index, 0, "no anomaly spawned in 400 days")
	var before: float = Game.sim.world.agent.compute
	var value: float = Game.sim.world.anomaly_in_region(index).value
	EventBus.region_selected.emit(index)
	assert_true((_node("AnomalyBox") as Control).visible)
	(_node("CollectButton") as Button).emit_signal("pressed")
	assert_almost_eq(Game.sim.world.agent.compute, before + value, 0.001)
	assert_null(Game.sim.world.anomaly_in_region(index), "the anomaly was taken")
	assert_false((_node("AnomalyBox") as Control).visible, "and the offer is gone")


# ----------------------------------------------- m3-screens §8.1 dormancy


func test_dormancy_toggle_sends_the_command() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	var row: Control = _panel.get_node("%DormancyRow") as Control
	EventBus.region_selected.emit(1)
	assert_false(row.visible, "without the branch there is nothing to hold")

	Game.sim.world.agent.compute += 400.0
	for node_id: String in DORMANCY_CHAIN:
		assert_true(Game.apply(PurchaseNodeCommand.new(node_id)).ok, node_id)
	_panel.refresh()
	assert_true(row.visible)

	var button: ConsoleButton = _panel.get_node("%DormancyButton") as ConsoleButton
	button.emit_signal("pressed")
	assert_true(Game.sim.world.regions[1].dormant, "the region is held")
	assert_string_contains(_chip_texts(), tr("UI_REGION_STATE_DORMANT").to_upper())

	button.emit_signal("pressed")
	assert_false(Game.sim.world.regions[1].dormant, "and woken again")


func test_the_dormancy_row_is_disabled_where_there_is_no_presence() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))
	Game.sim.world.agent.compute += 400.0
	for node_id: String in DORMANCY_CHAIN:
		Game.apply(PurchaseNodeCommand.new(node_id))
	# A region the agent has never reached.
	var clean: int = _index_of_clean_region()
	EventBus.region_selected.emit(clean)
	_panel.refresh()
	var button: ConsoleButton = _panel.get_node("%DormancyButton") as ConsoleButton
	assert_true(button.disabled)


func _index_of_clean_region() -> int:
	for i: int in range(1, Game.sim.world.regions.size()):
		if Game.sim.world.regions[i].penetration <= 0.0:
			return i
	return 1


## Every chip's text, as one string — the panel builds its chips in code.
func _chip_texts() -> String:
	var chips: HFlowContainer = _panel.get_node("%Chips") as HFlowContainer
	var text: String = ""
	for child: Node in chips.get_children():
		for inner: Node in child.get_children():
			var label: Label = inner as Label
			if label != null:
				text += label.text + " "
	return text
