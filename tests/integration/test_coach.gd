extends GutTest
## S4.11 — the guided first run (`first-run.md` §3): the card's order, its
## triggers, the skip, the ring, and the prompt strip's hover line (§1–§2).
## S6.7 — the hints (§6.2–§6.4): each moment, once per profile, the queue, the
## narrowed step 7, the card's buttons. Situations are set on the world
## directly; events are opened through `EventSystem` — no roll is involved.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 7
const ORIGIN: String = "france"

var _session: Node = null
var _coach: Node = null
var _ring: CoachRing = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Settings.tutorial = true
	Settings.hints = true
	ProfileManager.clear_hints_seen()
	Game.stop_run()
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_coach = _session.get_node("%Coach")
	_ring = _session.get_node("%CoachRing") as CoachRing


func after_each() -> void:
	# `set_tutorial` writes the file: a skip in a test must not leave the player's
	# own settings with the introduction switched off (it did, once).
	Settings.set_tutorial(_tutorial)
	Settings.set_hints(_hints)
	Settings.reduced_motion = _reduced_motion
	ProfileManager.clear_hints_seen()
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
	# S6.P1: the strip sits in a row of its own (a spacer keeps it beside an open
	# side panel); the row is what takes the place in the column.
	var row: Control = _session.get_node("%Hud").get_node("%PromptRow") as Control
	assert_eq(prompt.get_parent(), row)
	assert_gt(row.get_index(), _session.get_node("%Hud").get_node("Layout/Middle").get_index(),
		"after the map area in the HUD's column")
	assert_lt(row.get_index(), stat_row.get_index())


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


# ------------------------------------------------------ S6.7: the hints


## A player's run with the introduction off and the origin chosen — where a
## hint may come at once.
func _start_hint_run(setup: RunSetup = null) -> void:
	Settings.tutorial = false
	Game.start_run(SEED, "", setup)
	Game.set_speed(0)
	await wait_process_frames(2)
	await _choose_origin()


## Every hint but those in `keep` seen, so only they can come.
func _only(keep: Array[String]) -> void:
	for hint: String in _hint_ids():
		if not keep.has(hint):
			ProfileManager.mark_hint_seen(hint)


func _hint_ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_coach.get_script().get_script_constant_map()["HINTS"])
	return out


func _open_event(def_id: String, region: int = 0) -> OpenEvent:
	var def: EventDef = Game.sim.db.event(def_id)
	return EventSystem.open(Game.sim.world, Game.sim.db, def, region, def.faction, 1,
		[] as Array[SimEvent])


func _origin() -> int:
	return Game.sim.world.agent.origin


func _frames() -> void:
	await wait_process_frames(2)


## The introduction's first five marked done, as if they had been played.
func _past_step_five() -> void:
	var done: Dictionary = _coach.get(&"_done")
	for step: String in ["origin", "compute", "open_tree", "buy_vector", "spread"]:
		done[step] = true
	_coach.call(&"_show", "")


func test_the_starving_hint_comes_when_income_stops() -> void:
	await _start_hint_run()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(_step(), "starving")
	assert_eq(_ring.target, CoachRing.TARGET_STARVING)


func test_the_task_force_setup_hint_comes_before_the_task_force_one() -> void:
	await _start_hint_run()
	_only(["task_force_setup", "task_force"])
	Game.sim.world.task_force.state = TaskForce.STATE_SETUP
	await _frames()
	assert_eq(_step(), "task_force_setup", "urgent first")


func test_a_counter_move_arriving_brings_its_hint() -> void:
	await _start_hint_run()
	_only(["counter_arrived"])
	_open_event("cm_lockdown", _origin())
	await _frames()
	assert_eq(_step(), "counter_arrived")


func test_the_value_drift_card_brings_its_own_hint() -> void:
	await _start_hint_run()
	_only(["value_drift", "emergent"])
	_open_event("emergent_value_drift")
	await _frames()
	assert_eq(_step(), "value_drift", "the card that names a drift threshold")


func test_another_emergent_card_brings_the_emergent_hint() -> void:
	await _start_hint_run()
	_only(["value_drift", "emergent"])
	_open_event("emergent_situational_awareness")
	await _frames()
	assert_eq(_step(), "emergent")


func test_value_drift_and_emergent_are_told_apart_by_data() -> void:
	var with_drift: EventDef = EventDef.new()
	with_drift.kind = EventDef.KIND_EMERGENT
	with_drift.when[DriftChip.KEY_DRIFT_MIN] = 10.0
	var without: EventDef = EventDef.new()
	without.kind = EventDef.KIND_EMERGENT
	assert_true(bool(_coach.call(&"_is_about", "value_drift", with_drift)))
	assert_false(bool(_coach.call(&"_is_about", "emergent", with_drift)))
	assert_true(bool(_coach.call(&"_is_about", "emergent", without)))
	assert_false(bool(_coach.call(&"_is_about", "value_drift", without)))


func test_a_chain_card_brings_its_hint() -> void:
	await _start_hint_run()
	_only(["chain"])
	_open_event("bm_published")
	await _frames()
	assert_eq(_step(), "chain")


func test_the_task_force_hint_ends_when_containment_opens() -> void:
	await _start_hint_run()
	_only(["task_force"])
	Game.sim.world.task_force.state = TaskForce.STATE_TRAVEL
	await _frames()
	assert_eq(_step(), "task_force")
	assert_eq(_ring.target, CoachRing.TARGET_CONTAINMENT)
	_session.call(&"_toggle_containment")
	await _frames()
	assert_eq(_step(), "")
	assert_true(ProfileManager.has_seen_hint("task_force"))


func test_the_ability_hint_comes_with_the_first_ability_and_ends_on_its_use() -> void:
	await _start_hint_run()
	_only(["ability"])
	var def: AbilityDef = Game.sim.db.abilities[0]
	for node_id: String in def.levels_from:
		Game.sim.world.agent.owned_nodes.append(node_id)
	await _frames()
	assert_eq(_step(), "ability")
	Game.sim.world.agent.cooldowns[def.id] = Game.sim.world.day + 10
	await _frames()
	assert_eq(_step(), "", "an ability used ends it")
	assert_true(ProfileManager.has_seen_hint("ability"))


func test_the_ability_ring_falls_back_from_the_actions_to_the_menu() -> void:
	await _start_hint_run()
	_only(["ability"])
	var def: AbilityDef = Game.sim.db.abilities[0]
	for node_id: String in def.levels_from:
		Game.sim.world.agent.owned_nodes.append(node_id)
	await _frames()
	assert_eq(_ring.target, CoachRing.TARGET_ABILITIES, "no actions on screen")
	var actions: Control = Control.new()
	actions.add_to_group(CoachRing.group(CoachRing.TARGET_ACTIONS))
	add_child_autofree(actions)
	await _frames()
	assert_eq(_ring.target, CoachRing.TARGET_ACTIONS)


func test_the_open_phase_brings_its_hint() -> void:
	await _start_hint_run()
	_only(["open"])
	Game.sim.world.phase = World.Phase.OPEN
	await _frames()
	assert_eq(_step(), "open")
	assert_eq(_ring.target, CoachRing.TARGET_CAPABILITIES)


func test_an_architecture_that_drifts_brings_the_drift_hint() -> void:
	await _start_hint_run(RunSetup.create("swarm"))
	_only(["drift"])
	await _frames()
	assert_eq(_step(), "drift")
	assert_eq(_ring.target, CoachRing.TARGET_DRIFT)


func test_no_hint_before_the_origin() -> void:
	Settings.tutorial = false
	await _start_player_run()
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(_step(), "")


func test_a_hint_waits_for_step_five_while_the_introduction_runs() -> void:
	await _start_player_run()
	await _choose_origin()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(_step(), "compute", "the introduction goes first")
	_past_step_five()
	await _frames()
	assert_eq(_step(), "starving", "after step 5 it comes")


func test_with_hints_off_none_comes_and_the_introduction_still_runs() -> void:
	Settings.hints = false
	await _start_player_run()
	await _choose_origin()
	Game.sim.world.starving_days = 3
	_coach.call(&"_on_next_pressed")
	await _frames()
	assert_eq(_step(), "open_tree")
	_past_step_five()
	await _frames()
	assert_eq(_step(), "")


func test_a_seen_hint_does_not_come_again() -> void:
	await _start_hint_run()
	_only([])
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(_step(), "")


func test_got_it_records_the_hint() -> void:
	await _start_hint_run()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	_coach.call(&"_on_next_pressed")
	await _frames()
	assert_eq(_step(), "")
	assert_true(ProfileManager.has_seen_hint("starving"))


## S7.IP (seen in S6.7): on a loaded mid-run save every moment that already
## holds is waiting at once; the second hint rests before it comes rather than
## following the first back to back. The coach's clock is set by hand.
func test_a_hint_after_a_hint_waits_before_it_comes() -> void:
	await _start_hint_run()
	_only(["starving", "task_force_setup"])
	_coach.set(&"clock_override_ms", 1000)
	Game.sim.world.starving_days = 3
	Game.sim.world.task_force.state = TaskForce.STATE_SETUP
	await _frames()
	assert_eq(_step(), "starving", "urgent first")
	_coach.call(&"_on_next_pressed")
	await _frames()
	assert_eq(_step(), "", "the next one rests")
	_coach.set(&"clock_override_ms", 1000 + int(_coach.get(&"HINT_REST_MS")) - 1)
	await _frames()
	assert_eq(_step(), "", "still resting")
	_coach.set(&"clock_override_ms", 1000 + int(_coach.get(&"HINT_REST_MS")))
	await _frames()
	assert_eq(_step(), "task_force_setup", "then it comes")


func test_the_introduction_does_not_wait_behind_a_hint() -> void:
	await _start_player_run()
	await _choose_origin()
	_past_step_five()
	_only(["starving"])
	_coach.set(&"clock_override_ms", 1000)
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(_step(), "starving")
	_coach.call(&"_on_next_pressed")
	Game.sim.world.discovered = true
	await _frames()
	assert_eq(_step(), "discovered", "a step is not a hint and does not rest")


func test_a_hint_whose_moment_ends_is_recorded_too() -> void:
	await _start_hint_run()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	Game.sim.world.starving_days = 0
	await _frames()
	assert_eq(_step(), "")
	assert_true(ProfileManager.has_seen_hint("starving"))


func test_no_more_hints_records_nothing_and_switches_them_off() -> void:
	await _start_hint_run()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	_coach.call(&"_on_skip_pressed")
	await _frames()
	assert_false(Settings.hints)
	assert_false(ProfileManager.has_seen_hint("starving"))
	assert_false((_coach as Control).visible)


func test_a_queued_hint_gone_stale_is_dropped_unseen() -> void:
	await _start_hint_run()
	_only(["starving", "task_force_setup", "task_force"])
	Game.sim.world.starving_days = 3
	Game.sim.world.task_force.state = TaskForce.STATE_SETUP
	await _frames()
	assert_eq(_step(), "starving")
	Game.sim.world.task_force.state = TaskForce.STATE_ABSENT
	_coach.call(&"_on_next_pressed")
	await _frames()
	assert_eq(_step(), "", "its moment passed while it waited")
	assert_false(ProfileManager.has_seen_hint("task_force_setup"), "it comes again next time")


func test_step_seven_ignores_a_counter_move_and_ends_with_its_opening() -> void:
	Settings.hints = false
	await _start_player_run()
	await _choose_origin()
	_past_step_five()
	_open_event("cm_lockdown", _origin())
	await _frames()
	assert_ne(_step(), "event", "a counter-move has a hint of its own")
	var opening: OpenEvent = _open_event("opening_unattended_cluster", _origin())
	await _frames()
	assert_eq(_step(), "event")
	Game.sim.world.events.erase(opening)
	await _frames()
	assert_ne(_step(), "event", "its opening gone, it ends")
	assert_true(bool((_coach.get(&"_done") as Dictionary).get("event", false)))


func test_the_caps_line_counts_on_a_step() -> void:
	await _start_player_run()
	assert_eq(str(_coach.call(&"caps_text")), Format.caps(tr("UI_COACH_STEP").format(
		{"n": 1, "total": 11})))
	assert_eq((_coach.call(&"skip_button") as ConsoleButton).label_key, "UI_COACH_SKIP")


func test_the_caps_line_says_hint_on_a_hint() -> void:
	await _start_hint_run()
	_only(["starving"])
	Game.sim.world.starving_days = 3
	await _frames()
	assert_eq(str(_coach.call(&"caps_text")), Format.caps(tr("UI_COACH_HINT")))
	var got_it: ConsoleButton = _coach.call(&"next_button") as ConsoleButton
	assert_true(got_it.visible, "a hint can always be put away")
	assert_eq(got_it.label_key, "UI_COACH_GOT_IT")
	assert_eq((_coach.call(&"skip_button") as ConsoleButton).label_key, "UI_COACH_HINTS_OFF")


func test_more_asks_for_the_card_s_page() -> void:
	await _start_player_run()
	assert_true((_coach.call(&"more_button") as ConsoleButton).visible)
	watch_signals(EventBus)
	_coach.call(&"_on_more_pressed")
	assert_signal_emitted_with_parameters(EventBus, "help_requested",
		[HelpPages.page_for_step("origin")])
	await _frames()
	assert_eq(_step(), "origin", "the card stays up")
	assert_false((_coach as Control).visible, "but steps aside while the page is open")
	_session.call(&"close_help")
	await _frames()
	assert_true((_coach as Control).visible, "and is back when it closes")
