extends GutTest
## S4.8 — the Analysis sheet in a session on `res://data` (analysis.md §5, §15).

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const AnalysisPanel: GDScript = preload("res://ui/panels/analysis_panel.gd")
const SEED: int = 1
const DAYS: int = 120

var _session: Control = null
var _panel: AnalysisPanel = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_panel = _session.get_node("%AnalysisPanel") as AnalysisPanel


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _start(days: int = DAYS) -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(days)


func _press_g() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_G
	key.pressed = true
	_session._input(key)


func test_g_opens_and_closes_the_sheet() -> void:
	_start()
	_press_g()
	assert_true(_panel.is_open)
	_press_g()
	assert_false(_panel.is_open)


func test_the_three_panels_never_share_the_screen() -> void:
	_start()
	var containment: SlidePanel = _session.get_node("PanelLayer/ContainmentPanel") as SlidePanel
	_press_g()
	EventBus.region_selected.emit(1)
	assert_false(_panel.is_open, "a region closes the sheet")
	_press_g()
	_session.call(&"_toggle_containment")
	assert_true(containment.is_open)
	assert_false(_panel.is_open, "the containment panel closes it")
	_press_g()
	assert_false(containment.is_open, "and the sheet closes the containment panel")


func test_the_run_tab_plots_every_sample() -> void:
	_start()
	_panel.open()
	var tab: AnalysisTab = _panel.tab(AnalysisPanel.Tab.RUN)
	assert_eq(tab.charts().size(), 4)
	for chart: LineChart in tab.charts():
		assert_eq(chart.series().size(), 1)
		assert_eq(chart.series()[0].days.size(), Game.sim.world.history.size(), chart.title_key)


func test_the_opposition_tab_puts_the_risk_first_until_they_know() -> void:
	_start(20)
	Game.sim.world.discovered = false
	_panel.open()
	_panel.select_tab(AnalysisPanel.Tab.OPPOSITION)
	var tab: AnalysisTab = _panel.tab(AnalysisPanel.Tab.OPPOSITION)
	assert_eq((tab.get_child(0) as LineChart).title_key, "UI_CHART_RISK")
	assert_true((tab.get_child(1) as Label).visible, "and the note under it")
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = Game.sim.world.day
	Game.advance(1)
	assert_eq((tab.get_child(tab.get_child_count() - 1) as LineChart).title_key, "UI_CHART_RISK",
		"after discovery the risk chart goes last")


func test_the_world_tab_has_four_small_multiples() -> void:
	_start()
	_panel.open()
	_panel.select_tab(AnalysisPanel.Tab.WORLD)
	var small: int = 0
	for chart: LineChart in _panel.tab(AnalysisPanel.Tab.WORLD).charts():
		if chart.small:
			small += 1
	assert_eq(small, 4)


func test_a_cursor_on_one_chart_moves_every_chart_of_the_tab() -> void:
	_start()
	_panel.open()
	var charts: Array[LineChart] = _panel.tab(AnalysisPanel.Tab.RUN).charts()
	charts[0].set_cursor(30)
	charts[0].cursor_moved.emit(charts[0].cursor_day())
	for chart: LineChart in charts:
		assert_eq(chart.cursor_day(), charts[0].cursor_day(), chart.title_key)


func test_the_table_replaces_the_charts_and_back() -> void:
	_start()
	_panel.open()
	_panel.set_table(true)
	assert_true(_panel.table().visible)
	assert_false(_panel.tab(AnalysisPanel.Tab.RUN).visible)
	assert_eq(_panel.table().columns, 5, "the day and four series")
	var rows: int = _panel.table().get_root().get_child_count()
	assert_gt(rows, 1)
	assert_lte(rows, UiTokens.TABLE_ROWS + 1)
	_panel.set_table(false)
	assert_false(_panel.table().visible)
	assert_true(_panel.tab(AnalysisPanel.Tab.RUN).visible)


func test_the_log_lists_the_run_and_filters_it() -> void:
	_start()
	_panel.open()
	_panel.select_tab(AnalysisPanel.Tab.LOG)
	var all: int = _panel.log_rows().size()
	assert_eq(all, Game.sim.world.run_log.size())
	_panel.set_log_filter(AnalysisPanel.Filter.YOURS)
	var yours: int = _panel.log_rows().size()
	_panel.set_log_filter(AnalysisPanel.Filter.THEIRS)
	assert_eq(yours + _panel.log_rows().size(), all)


func test_a_log_row_about_a_region_takes_you_there() -> void:
	_start()
	_panel.open()
	_panel.select_tab(AnalysisPanel.Tab.LOG)
	var chosen: Array[int] = []
	EventBus.region_selected.connect(func(index: int) -> void: chosen.append(index))
	var button: ConsoleButton = _panel.log_rows()[0] as ConsoleButton
	assert_not_null(button, "the origin line is a way to the origin")
	button.pressed.emit()
	assert_eq(chosen, [Game.sim.world.agent.origin] as Array[int])
	assert_false(_panel.is_open)


func test_a_loaded_save_shows_the_same_panel() -> void:
	_start()
	var sizes: Array[int] = [Game.sim.world.history.size(), Game.sim.world.run_log.size()]
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(Game.sim), Game.db)
	assert_true(loaded.ok(), loaded.reason)
	Game.adopt_loaded(loaded.sim)
	_panel.open()
	assert_eq(_panel.tab(AnalysisPanel.Tab.RUN).charts()[0].series()[0].days.size(), sizes[0])
	_panel.select_tab(AnalysisPanel.Tab.LOG)
	assert_eq(_panel.log_rows().size(), sizes[1])


func test_review_opens_from_the_results_and_goes_back() -> void:
	_start()
	var results: Control = _session.get_node("%Results") as Control
	var modals: ModalHost = _session.get_node("%ModalHost") as ModalHost
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	modals.open(results)
	results.emit_signal("review_requested")
	assert_true(_panel.is_open)
	assert_false(modals.is_open())
	_panel.close()
	assert_eq(modals.current(), results, "back to the results")
