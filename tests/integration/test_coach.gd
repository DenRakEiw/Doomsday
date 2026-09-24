extends GutTest
## S4.11 — the guided first run (`first-run.md` §3): the card's order, its
## triggers, the skip, the ring, and the prompt strip's hover line (§1–§2).

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 7
const ORIGIN: String = "france"

var _session: Node = null
var _coach: Node = null
var _ring: CoachRing = null
var _tutorial: bool = true
var _reduced_motion: bool = false


func before_each() -> void:
	_tutorial = Settings.tutorial
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Settings.tutorial = true
	Game.stop_run()
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_coach = _session.get_node("%Coach")
	_ring = _session.get_node("%CoachRing") as CoachRing


func after_each() -> void:
	Settings.tutorial = _tutorial
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func _step() -> String:
	return str(_coach.call(&"current_step"))


func _start_player_run() -> void:
	Game.start_run(SEED)
	Game.set_speed(0)
	await wait_process_frames(2)


func _choose_origin() -> void:
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	await wait_process_frames(2)


func test_a_players_run_starts_with_the_origin_step() -> void:
	await _start_player_run()
	assert_eq(_step(), "origin")
	assert_true((_coach as Control).visible)
	assert_eq(_ring.target, CoachRing.TARGET_ORIGIN_BUTTON)


func test_choosing_the_origin_moves_to_the_next_step() -> void:
	await _start_player_run()
	await _choose_origin()
	assert_eq(_step(), "compute")


func test_next_ends_a_step_that_is_read() -> void:
	await _start_player_run()
	await _choose_origin()
	_coach.call(&"_on_next_pressed")
	await wait_process_frames(2)
	assert_eq(_step(), "open_tree")
	assert_eq(_ring.target, CoachRing.TARGET_CAPABILITIES)


func test_opening_the_tree_leads_to_the_vector_and_buying_it_ends_that() -> void:
	await _start_player_run()
	await _choose_origin()
	_coach.call(&"_on_next_pressed")
	await wait_process_frames(2)
	_session.call(&"_toggle_tech_tree")
	await wait_process_frames(3)
	assert_eq(_step(), "buy_vector")
	var vector: Control = CoachRing.find(get_tree(), CoachRing.TARGET_VECTOR)
	assert_not_null(vector, "the board marks an affordable vector")
	Game.sim.world.agent.compute = 100.0
	Game.apply(PurchaseNodeCommand.new("cloud_federation"))
	await wait_process_frames(2)
	assert_eq(_step(), "spread")


func test_skipping_ends_the_introduction_for_good() -> void:
	await _start_player_run()
	_coach.call(&"_on_skip_pressed")
	await wait_process_frames(2)
	assert_false(Settings.tutorial)
	assert_false((_coach as Control).visible)
	assert_eq(_ring.target, "")


func test_a_bot_run_shows_nothing() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	await wait_process_frames(2)
	assert_eq(_step(), "")
	assert_false((_coach as Control).visible)


func test_the_ring_finds_nothing_without_a_visible_member() -> void:
	assert_null(CoachRing.find(get_tree(), "no_such_target"))
	assert_null(CoachRing.find(get_tree(), ""))


func test_the_prompt_strip_sits_below_the_map() -> void:
	await _start_player_run()
	var prompt: Control = _session.get_node("%Hud").get_node("%SitePrompt") as Control
	var stat_row: Control = _session.get_node("%Hud").get_node("%StatRow") as Control
	assert_true(prompt.visible)
	assert_gt(prompt.get_index(), _session.get_node("%Hud").get_node("Layout/Middle").get_index(),
		"after the map area in the HUD's column")
	assert_lt(prompt.get_index(), stat_row.get_index())


func test_folding_the_strip_keeps_the_choice_open() -> void:
	await _start_player_run()
	var prompt: Node = _session.get_node("%Hud").get_node("%SitePrompt")
	prompt.set(&"collapsed", true)
	assert_not_null(Game.site_request, "folding is not cancelling")
	assert_false((prompt.get_node("%SitePromptDetail") as Control).visible)


func test_hovering_a_closed_region_says_why() -> void:
	await _start_player_run()
	var prompt: Node = _session.get_node("%Hud").get_node("%SitePrompt")
	var detail: Label = prompt.get_node("%SitePromptDetail") as Label
	var closed: int = -1
	for i: int in range(1, Game.db.regions.size()):
		if not Game.site_request.reason_for(i).is_empty():
			closed = i
			break
	assert_gt(closed, 0, "the map has a region nobody can start in")
	EventBus.region_hovered.emit(closed)
	assert_string_contains(detail.text, Game.site_request.reason_text(closed))
	EventBus.region_hovered.emit(Game.db.region_index_by_id[ORIGIN])
	assert_eq(detail.text, tr("UI_SITE_HOVER_OK").format({"region": tr("REGION_FRANCE")}))
