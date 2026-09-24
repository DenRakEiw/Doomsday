extends GutTest
## S4.2 — the interface of the statuses and abilities
## (`docs/specs/loop-mechanics.md` §16.2, §16.5, §16.9, §16.10).
##
## One run on `res://data`, driven by hand: the panels, the picker and the
## console line all read the same world, so they are checked against it rather
## than against each other.

const PANEL_SCENE: PackedScene = preload("res://ui/panels/region_panel.tscn")
const PICKER_SCENE: PackedScene = preload("res://ui/modals/ability_picker.tscn")
const CONSOLE_SCENE: PackedScene = preload("res://ui/hud/console_line.tscn")
const READOUT: GDScript = preload("res://ui/hud/asset_readout.gd")

const SEED: int = 1
const REGION_USA: String = "usa"
## The shortest way to Harvest: a vector that reaches the USA, then the node
## that grants the ability (`data/abilities.json`).
const HARVEST_CHAIN: Array[String] = ["cloud_federation", "edge_caching"]
const HARVEST: String = "harvest"
const HARVESTED: String = "harvested"

var _root: Control = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_root.size = Vector2(1920.0, 1080.0)
	add_child_autofree(_root)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


## A player's run with Harvest bought and the clock stopped.
func _start_with_harvest() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))
	Game.sim.world.agent.compute += 500.0
	for node_id: String in HARVEST_CHAIN:
		var result: CommandResult = Game.apply(PurchaseNodeCommand.new(node_id))
		assert_true(result.ok, "%s: %s" % [node_id, result.reason])


func _index_of(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


# ------------------------------------------------------ the region panel


func _panel() -> SlidePanel:
	var panel: SlidePanel = PANEL_SCENE.instantiate() as SlidePanel
	_root.add_child(panel)
	return panel


func _rows(panel: SlidePanel, unique: String) -> Array[Node]:
	return (panel.get_node("%" + unique) as Control).get_children()


func test_the_actions_row_appears_with_the_first_ability() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))
	var panel: SlidePanel = _panel()
	EventBus.region_selected.emit(_index_of(REGION_USA))
	assert_false((panel.get_node("%ActionsBlock") as Control).visible,
		"nothing is unlocked yet")

	Game.sim.world.agent.compute += 500.0
	for node_id: String in HARVEST_CHAIN:
		Game.apply(PurchaseNodeCommand.new(node_id))
	assert_true((panel.get_node("%ActionsBlock") as Control).visible)
	assert_eq(_rows(panel, "Actions").size(), 1, "one button per unlocked region ability")


func test_the_action_button_sends_the_ability_and_the_status_appears() -> void:
	_start_with_harvest()
	var panel: SlidePanel = _panel()
	var index: int = _index_of(REGION_USA)
	EventBus.region_selected.emit(index)
	var row: Control = _rows(panel, "Actions")[0] as Control
	var button: Button = row.get_child(0).get_child(0) as Button
	assert_false(button.disabled, "the origin takes a Harvest")
	button.emit_signal("pressed")

	assert_true(Game.sim.world.has_status(HARVESTED, index), "within the same command")
	assert_true((panel.get_node("%StatusBlock") as Control).visible)
	assert_eq(_rows(panel, "Statuses").size(), 1)


func test_the_button_is_disabled_on_cooldown_and_says_when_it_is_back() -> void:
	_start_with_harvest()
	var panel: SlidePanel = _panel()
	var index: int = _index_of(REGION_USA)
	EventBus.region_selected.emit(index)
	(_rows(panel, "Actions")[0].get_child(0).get_child(0) as Button).emit_signal("pressed")
	panel.call("refresh")
	var row: Control = _rows(panel, "Actions")[0] as Control
	assert_true((row.get_child(0).get_child(0) as Button).disabled)
	var caption: Label = row.get_child(1) as Label
	assert_true(caption.visible)
	assert_string_contains(caption.text, "Ready in")


func test_a_status_row_says_what_it_is_whose_it_is_and_how_long() -> void:
	_start_with_harvest()
	var index: int = _index_of(REGION_USA)
	Game.apply(UseAbilityCommand.new(HARVEST, REGION_USA))
	var panel: SlidePanel = _panel()
	EventBus.region_selected.emit(index)
	var row: Control = _rows(panel, "Statuses")[0] as Control
	var head: Control = row.get_child(0) as Control
	assert_eq((head.get_child(1) as Label).text, tr(StatusDef.name_key(HARVESTED)))
	var days: Label = head.get_child(2) as Label
	assert_string_contains(days.text,
		str(Game.sim.world.status_in_region(HARVESTED, index).days_left(Game.sim.world.day)))
	assert_eq((row.get_child(1) as Label).text, tr("UI_REGION_STATUS_YOURS"))


func test_the_status_row_goes_when_the_status_does() -> void:
	_start_with_harvest()
	var index: int = _index_of(REGION_USA)
	Game.apply(UseAbilityCommand.new(HARVEST, REGION_USA))
	var panel: SlidePanel = _panel()
	EventBus.region_selected.emit(index)
	assert_true((panel.get_node("%StatusBlock") as Control).visible)
	Game.advance(Game.sim.world.status_in_region(HARVESTED, index).days_total() + 1)
	assert_false(Game.sim.world.has_status(HARVESTED, index))
	assert_false((panel.get_node("%StatusBlock") as Control).visible)


# ---------------------------------------------------------- the ability picker


func _picker() -> Control:
	var picker: Control = PICKER_SCENE.instantiate() as Control
	_root.add_child(picker)
	picker.call("refresh")
	return picker


func test_the_picker_lists_what_is_unlocked_and_nothing_else() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))
	var picker: Control = _picker()
	assert_eq(int(picker.call("shown")), 0)
	assert_true((picker.get_node("%AbilitiesEmpty") as Control).visible)

	Game.sim.world.agent.compute += 500.0
	for node_id: String in HARVEST_CHAIN:
		Game.apply(PurchaseNodeCommand.new(node_id))
	picker.call("refresh")
	assert_eq(int(picker.call("shown")), 1)
	assert_false((picker.get_node("%AbilitiesEmpty") as Control).visible)


## §16.10: a region ability hands the question to the map rather than acting.
func test_a_region_ability_enters_site_select_and_pays_nothing_yet() -> void:
	_start_with_harvest()
	var picker: Control = _picker()
	var before: float = Game.sim.world.agent.compute
	var row: Control = (picker.get_node("%AbilitiesList") as Control).get_child(0) as Control
	(row.get_child(0).get_child(0) as Button).emit_signal("pressed")

	assert_true(Game.is_selecting_site())
	assert_eq(Game.site_request.kind, SiteRequest.KIND_ABILITY)
	assert_eq(Game.site_request.title_key, "UI_SITE_PROMPT_ABILITY")
	assert_almost_eq(Game.sim.world.agent.compute, before, 1e-9, "nothing was paid")

	# And the region that takes it is the one the command would accept.
	assert_eq(Game.site_request.reason_for(_index_of(REGION_USA)), "")
	assert_true(Game.site_confirm(REGION_USA).ok)
	assert_true(Game.sim.world.has_status(HARVESTED, _index_of(REGION_USA)))
	assert_false(Game.is_selecting_site())


func test_the_picker_says_nothing_is_there_before_anything_is() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	var picker: Control = _picker()
	assert_eq((picker.get_node("%AbilitiesEmpty") as Label).text, tr("UI_ABILITIES_NONE"))


# ------------------------------------------------------------ the console line


func _console() -> Label:
	var line: Label = CONSOLE_SCENE.instantiate() as Label
	_root.add_child(line)
	return line


func test_the_console_line_says_what_an_ability_did() -> void:
	_start_with_harvest()
	var line: Label = _console()
	Game.apply(UseAbilityCommand.new(HARVEST, REGION_USA))
	assert_true(bool(line.call("is_showing")))
	assert_string_contains(line.text, tr(AbilityDef.name_key(HARVEST)))
	assert_string_contains(line.text, tr("REGION_USA"))


## §16.2: the queue keeps the newest three and drops the rest.
func test_the_queue_keeps_the_newest_three() -> void:
	_start_with_harvest()
	var line: Label = _console()
	for i: int in 9:
		line.call("push", "line %d" % i)
	assert_true(bool(line.call("is_showing")))
	assert_eq(int(line.call("queued")), UiTokens.CONSOLE_QUEUE_MAX)


## §16.2: a bot run is narrated by the ticker alone.
func test_a_bot_run_says_nothing() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	var line: Label = _console()
	Game.advance(40)
	line.call("push", "anything")
	assert_false(line.visible)
	assert_eq(int(line.call("queued")), 0)


func test_a_new_run_clears_the_line() -> void:
	_start_with_harvest()
	var line: Label = _console()
	line.call("push", "something")
	Game.start_run(SEED + 1)
	assert_false(line.visible)
	assert_eq(int(line.call("queued")), 0)


# ---------------------------------------------- the readout's global statuses


func test_a_global_status_shows_as_a_chip_in_the_readout() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))
	var readout: HBoxContainer = READOUT.new() as HBoxContainer
	_root.add_child(readout)
	assert_eq(int(readout.call("status_chip_count")), 0)

	var events: Array[SimEvent] = []
	StatusSystem.apply(Game.sim.world, Game.db, "paused", 0, Status.SOURCE_EFFECT, 1, "",
		events)
	readout.call("refresh")
	assert_eq(int(readout.call("status_chip_count")), 1)
	assert_true(readout.visible, "a global status alone is worth the row")


func test_a_faction_status_names_the_answer_in_words() -> void:
	# S4.P: the line printed the option's id (`Regierungen · ride`).
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(REGION_USA))
	var index: int = _index_of(REGION_USA)
	var move: EventDef = Game.db.event("cm_lockdown")
	StatusSystem.apply(Game.sim.world, Game.db, move.status, index,
		Status.source_for(Status.SOURCE_FACTION, move.faction), 1, "ride", [] as Array[SimEvent])
	var panel: SlidePanel = _panel()
	EventBus.region_selected.emit(index)
	var line: String = ((_rows(panel, "Statuses")[0] as Control).get_child(1) as Label).text
	assert_string_contains(line, tr("EVENT_CM_LOCKDOWN_OPT_RIDE"))
	assert_false(line.ends_with("ride"), "the id is not what the player reads")
