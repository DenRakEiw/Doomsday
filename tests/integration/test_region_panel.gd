extends GutTest
## S2.5 — the region panel against a running simulation (spec ui-foundation.md
## §5.6).
##
## A selection is a signal, not a method call: the panel opens on
## `region_selected` and closes on `region_selected(0)`, which is what the close
## button, `Escape` and a tap on the ocean all produce.

const PANEL_SCENE: PackedScene = preload("res://ui/panels/region_panel.tscn")

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


func test_escape_closes_the_panel() -> void:
	_start()
	_select(REGION_USA)
	watch_signals(EventBus)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	# The shortcut layer, not unhandled input: a focused button would otherwise
	# have swallowed the key before the panel saw it.
	_panel.call("_shortcut_input", key)
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
