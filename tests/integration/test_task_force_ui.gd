extends GutTest
## S5.5 — the Response Task Force in the interface (`taskforce-endings.md` §2.3,
## §9): its marker and road on the map, its rows in the region and containment
## panels, its console and log lines, and Misdirect offered only while there is
## a team to mislead.

const SESSION_SCENE: PackedScene = preload("res://game/session/session.tscn")

const SEED: int = 1
const ORIGIN: String = "usa"
const NEIGHBOUR: String = "canada"
const MISDIRECT: String = "misdirect"
const MISDIRECT_CHAIN: Array[String] = ["log_manipulation_1", "log_manipulation_2"]

var _session: Node = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION_SCENE.instantiate()
	add_child_autofree(_session)
	Game.start_run(SEED)
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(ORIGIN))


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _index_of(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


func _markers() -> Node2D:
	return _session.get_node("MapLayer/MarkerLayer") as Node2D


func _team_marker() -> TaskForceMarker:
	return _markers().call("team_marker") as TaskForceMarker


## Puts the team where a test needs it and tells the interface, as a tick would.
func _place(state: String, region_id: String, target_id: String = "",
		action: String = "") -> void:
	var team: TaskForce = Game.sim.world.task_force
	team.state = state
	team.region = _index_of(region_id)
	team.target = _index_of(target_id) if not target_id.is_empty() else 0
	team.action = action
	team.level = 1
	team.progress = 0.0
	EventBus.sim_event.emit(SimEvent.new(SimEvent.TASK_FORCE_MOVED, Game.sim.world.day, {}))


# ------------------------------------------------------------------- the map


func test_no_team_no_marker() -> void:
	assert_null(_team_marker())


func test_the_marker_stands_on_the_teams_region_with_its_letters() -> void:
	_place(TaskForce.STATE_REST, ORIGIN)
	var marker: TaskForceMarker = _team_marker()
	assert_not_null(marker)
	assert_eq(marker.position, Vector2(Game.sim.world.regions[_index_of(ORIGIN)].def.anchor))
	assert_eq(marker.code, tr("UI_TASK_FORCE_CODE"))
	assert_lt(marker.share, 0.0, "no ring while it rests")


func test_a_setup_counts_down_on_the_marker() -> void:
	_place(TaskForce.STATE_SETUP, ORIGIN, ORIGIN, "grid_down")
	assert_almost_eq(_team_marker().share, 1.0, 1e-6)
	Game.sim.world.task_force.progress = 2.0
	EventBus.tick_advanced.emit(Game.sim.world.day)
	assert_between(_team_marker().share, 0.01, 0.99)


func test_the_road_is_hidden_unless_the_player_may_see_it() -> void:
	_place(TaskForce.STATE_TRAVEL, ORIGIN, NEIGHBOUR)
	assert_eq(int(_markers().call("team_line_target")), 0, "§2.3: only once it sets up")
	Game.sim.world.agent.story_flags.append(TaskForceSystem.FLAG_ALLY)
	EventBus.tick_advanced.emit(Game.sim.world.day)
	assert_eq(int(_markers().call("team_line_target")), _index_of(NEIGHBOUR))


func test_the_watcher_node_shows_the_road_too() -> void:
	Game.sim.world.agent.compute += 500.0
	assert_true(Game.apply(PurchaseNodeCommand.new("early_warning_intrusion")).ok)
	_place(TaskForce.STATE_TRAVEL, ORIGIN, NEIGHBOUR)
	assert_eq(int(_markers().call("team_line_target")), _index_of(NEIGHBOUR))


## §9's G5 (1/3) amendment: the team wears red — dimmed on the move, full in
## the moment before it acts.
func test_the_marker_is_dim_red_while_travelling_and_red_while_setting_up() -> void:
	_place(TaskForce.STATE_TRAVEL, ORIGIN, NEIGHBOUR)
	assert_eq(_team_marker().stroke_color(), UiTokens.color(&"TASK_FORCE_DIM"))
	_place(TaskForce.STATE_REST, ORIGIN)
	assert_eq(_team_marker().stroke_color(), UiTokens.color(&"TASK_FORCE_DIM"))
	_place(TaskForce.STATE_SETUP, ORIGIN, ORIGIN, "grid_down")
	assert_eq(_team_marker().stroke_color(), UiTokens.color(&"TASK_FORCE"))


func test_a_team_status_is_red_and_a_player_status_still_accent() -> void:
	assert_eq(UiTokens.status_token(TaskForceSystem.SOURCE), &"TASK_FORCE")
	assert_eq(UiTokens.status_color(TaskForceSystem.SOURCE), UiTokens.color(&"TASK_FORCE"))
	var ability: String = Status.source_for(Status.SOURCE_ABILITY, "harvest")
	assert_eq(UiTokens.status_token(ability), &"ACCENT")
	var faction: String = Status.source_for(Status.SOURCE_FACTION, "governments")
	assert_eq(UiTokens.status_token(faction), &"FACTION_GOVERNMENTS")


## By its source, never by the `tf_` prefix of its id.
func test_a_status_is_the_teams_by_its_source_not_its_id() -> void:
	var events: Array[SimEvent] = []
	var region: int = _index_of(NEIGHBOUR)
	var status: Status = StatusSystem.apply(Game.sim.world, Game.db, "tf_raid", region,
		TaskForceSystem.SOURCE, 1, "", events)
	assert_eq(RegionData.status_index(Game.sim.world, region), RegionData.STATUS_TASK_FORCE)
	var chip: Chip = Chip.new()
	add_child_autofree(chip)
	chip.set_status_source(status.source)
	assert_eq(chip.kind, Chip.Kind.TASK_FORCE)
	assert_eq(String(chip.theme_type_variation), "ChipTaskForce")
	StatusSystem.end(Game.sim.world, Game.db, status, StatusSystem.CAUSE_ENDED, events)
	StatusSystem.apply(Game.sim.world, Game.db, "tf_raid", region,
		Status.source_for(Status.SOURCE_EFFECT, "test"), 1, "", events)
	assert_eq(RegionData.status_index(Game.sim.world, region), RegionData.STATUS_PLAYER,
		"the same id from any other source keeps the old colour")


func test_the_marker_goes_when_the_team_does() -> void:
	_place(TaskForce.STATE_REST, ORIGIN)
	Game.sim.world.task_force = TaskForce.new()
	EventBus.tick_advanced.emit(Game.sim.world.day)
	assert_null(_team_marker())


# ------------------------------------------------------------------- the panels


func test_the_region_panel_names_the_setup_and_its_days() -> void:
	_place(TaskForce.STATE_SETUP, ORIGIN, ORIGIN, "grid_down")
	var panel: Control = _session.get_node("PanelLayer/RegionPanel") as Control
	EventBus.region_selected.emit(_index_of(ORIGIN))
	panel.call("refresh")
	assert_true((panel.get_node("%TaskForceRow") as Control).visible)
	var line: String = (panel.get_node("%TaskForceLine") as Label).text
	assert_string_contains(line, tr("STATUS_TF_GRID_DOWN_NAME"))
	assert_string_contains(line, str(TaskForceSystem.setup_days(Game.sim.world, Game.db)))


func test_the_region_panel_says_nothing_of_a_hidden_target() -> void:
	_place(TaskForce.STATE_TRAVEL, ORIGIN, NEIGHBOUR)
	var panel: Control = _session.get_node("PanelLayer/RegionPanel") as Control
	EventBus.region_selected.emit(_index_of(NEIGHBOUR))
	panel.call("refresh")
	assert_false((panel.get_node("%TaskForceRow") as Control).visible)
	Game.sim.world.agent.story_flags.append(TaskForceSystem.FLAG_ALLY)
	panel.call("refresh")
	assert_eq((panel.get_node("%TaskForceLine") as Label).text, tr("UI_TASK_FORCE_TARGET"))


func test_the_containment_panel_has_the_teams_row_after_discovery() -> void:
	var panel: Control = _session.get_node("PanelLayer/ContainmentPanel") as Control
	panel.call("open")
	assert_false((panel.get_node("%TaskForceBlock") as Control).visible)
	Game.sim.world.discovered = true
	panel.call("refresh")
	assert_eq((panel.get_node("%TaskForceState") as Label).text,
		tr("UI_TASK_FORCE_STATE_ABSENT"))
	_place(TaskForce.STATE_TRAVEL, ORIGIN, NEIGHBOUR)
	panel.call("refresh")
	var line: String = (panel.get_node("%TaskForceState") as Label).text
	assert_string_contains(line, tr("UI_TASK_FORCE_LEVEL").format({"level": 1}))
	assert_string_contains(line, tr("UI_TASK_FORCE_STATE_TRAVEL_UNKNOWN"))


## S5.9 (§14.4): the mark's line, with the days left, whatever the team does.
func test_the_marked_line_counts_the_days_left_and_is_empty_unmarked() -> void:
	var world: World = Game.sim.world
	assert_eq(TaskForceText.marked_line(world, Game.db, _index_of(ORIGIN)), "")
	world.task_force.marked[_index_of(ORIGIN)] = world.day + 12
	assert_eq(TaskForceText.marked_line(world, Game.db, _index_of(ORIGIN)),
		tr("UI_TASK_FORCE_MARKED").format({"days": 12}))
	assert_eq(TaskForceText.marked_line(world, Game.db, _index_of(NEIGHBOUR)), "")
	world.day += 12
	assert_eq(TaskForceText.marked_line(world, Game.db, _index_of(ORIGIN)), "", "run out")


func test_the_region_panel_shows_the_mark_with_no_team_there() -> void:
	var world: World = Game.sim.world
	world.task_force.marked[_index_of(ORIGIN)] = world.day + 30
	var panel: Control = _session.get_node("PanelLayer/RegionPanel") as Control
	EventBus.region_selected.emit(_index_of(ORIGIN))
	panel.call("refresh")
	assert_false((panel.get_node("%TaskForceRow") as Control).visible, "the team is absent")
	var marked: Label = panel.get_node("%TaskForceMarked") as Label
	assert_true(marked.visible)
	assert_eq(marked.text, tr("UI_TASK_FORCE_MARKED").format({"days": 30}))
	world.task_force.marked.clear()
	panel.call("refresh")
	assert_false(marked.visible)


# ------------------------------------------------------ the console and the log


func test_a_setup_slept_through_speaks_once_through_the_mark() -> void:
	var fizzled: SimEvent = SimEvent.new(SimEvent.TASK_FORCE_FIZZLED, 1,
		{"region": ORIGIN, "action": "grid_down", "cause": TaskForceSystem.CAUSE_DORMANT})
	assert_eq(TaskForceText.console_line(fizzled, Game.sim.world, Game.db), "")
	var marked: SimEvent = SimEvent.new(SimEvent.TASK_FORCE_MARKED, 1,
		{"region": ORIGIN, "days": 40})
	assert_eq(TaskForceText.console_line(marked, Game.sim.world, Game.db),
		tr("UI_CONSOLE_TF_MARKED").format({"region": tr("REGION_USA"), "days": 40}))
	var clean: SimEvent = SimEvent.new(SimEvent.TASK_FORCE_FIZZLED, 1,
		{"region": ORIGIN, "action": "grid_down", "cause": TaskForceSystem.CAUSE_CLEAN})
	assert_ne(TaskForceText.console_line(clean, Game.sim.world, Game.db), "",
		"any other fizzle still has its line")


func _console() -> Label:
	return _session.get_node("HudLayer/SafeArea/Hud/Layout/ConsoleLine") as Label


func test_the_console_says_the_team_formed_and_where() -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.TASK_FORCE_APPEARED, 1, {"region": ORIGIN}))
	assert_eq(_console().text, tr("UI_CONSOLE_TF_APPEARED").format({"region": tr("REGION_USA")}))


func test_its_status_is_not_announced_as_yours() -> void:
	var line: Label = _console()
	line.call("clear")
	EventBus.sim_event.emit(SimEvent.new(SimEvent.STATUS_STARTED, 1,
		{"status": "tf_grid_down", "region": ORIGIN, "source": TaskForceSystem.SOURCE}))
	assert_eq(int(line.call("queued")), 0)
	assert_false(bool(line.call("is_showing")))


func test_an_action_is_one_log_line_not_two() -> void:
	var events: Array[SimEvent] = []
	StatusSystem.apply(Game.sim.world, Game.db, "tf_grid_down", _index_of(ORIGIN),
		TaskForceSystem.SOURCE, 1, "", events)
	events.append(SimEvent.new(SimEvent.TASK_FORCE_ACTED, Game.sim.world.day,
		{"region": ORIGIN, "action": "grid_down"}))
	var before: int = Game.sim.world.run_log.size()
	RunLog.record(Game.sim.world, Game.db, events)
	assert_eq(Game.sim.world.run_log.size(), before + 1)
	var entry: RunLogEntry = Game.sim.world.run_log.back()
	assert_eq(RunLogText.text(entry, Game.db), tr("UI_LOG_TF_ACTED").format(
		{"region": tr("REGION_USA"), "action": tr("STATUS_TF_GRID_DOWN_NAME")}))


# ------------------------------------------------------------------ Misdirect


func _own_misdirect() -> void:
	Game.sim.world.agent.compute += 500.0
	for node_id: String in MISDIRECT_CHAIN:
		var result: CommandResult = Game.apply(PurchaseNodeCommand.new(node_id))
		assert_true(result.ok, "%s: %s" % [node_id, result.reason])


func test_misdirect_is_offered_only_while_there_is_a_team() -> void:
	_own_misdirect()
	var panel: Control = _session.get_node("PanelLayer/RegionPanel") as Control
	EventBus.region_selected.emit(_index_of(NEIGHBOUR))
	panel.call("refresh")
	for row: Node in (panel.get_node("%Actions") as Node).get_children():
		assert_false((row.get_child(0).get_child(0) as ConsoleButton).label_key
			== AbilityDef.name_key(MISDIRECT), "no team, no Misdirect")
	_place(TaskForce.STATE_TRAVEL, ORIGIN, ORIGIN)
	panel.call("refresh")
	var keys: Array[String] = []
	for row: Node in (panel.get_node("%Actions") as Node).get_children():
		keys.append((row.get_child(0).get_child(0) as ConsoleButton).label_key)
	assert_has(keys, AbilityDef.name_key(MISDIRECT))


func test_the_picker_greys_misdirect_out_and_says_why() -> void:
	_own_misdirect()
	var picker: Control = _session.get_node("ModalLayer/ModalHost/AbilityPicker") as Control
	picker.call("refresh")
	var found: bool = false
	for row: Node in (picker.get_node("%AbilitiesList") as Node).get_children():
		var button: ConsoleButton = row.get_child(0).get_child(0) as ConsoleButton
		if button.label_key != AbilityDef.name_key(MISDIRECT):
			continue
		found = true
		assert_true(button.disabled)
		assert_eq((row.get_child(1) as Label).text, tr("CMD_FAIL_NO_TASK_FORCE"))
	assert_true(found)
