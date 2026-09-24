extends GutTest
## S5.7 — what a run adds to the Codex (spec screens-full.md §5.1): each source
## once, the merge on autosave and at the run's end, the count of new entries,
## and ids the content no longer has.

const SESSION: PackedScene = preload("res://game/session/session.tscn")

var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	ProfileManager.reset()
	SaveManager.delete(SaveManager.AUTOSAVE)


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	SaveManager.delete(SaveManager.AUTOSAVE)
	Game.stop_run()
	ProfileManager.reset()


func _event(type: String, data: Dictionary) -> SimEvent:
	return SimEvent.new(type, 1, data)


func _tracker() -> CodexTracker:
	var tracker: CodexTracker = CodexTracker.new()
	autofree(tracker)
	return tracker


func test_each_source_adds_its_id_once() -> void:
	var tracker: CodexTracker = _tracker()
	tracker.take(_event(SimEvent.ORIGIN_CHOSEN, {"region": "usa"}))
	tracker.take(_event(SimEvent.REGION_SEEDED, {"region": "usa"}))
	tracker.take(_event(SimEvent.REGION_SEEDED, {"region": "canada"}))
	tracker.take(_event(SimEvent.NODE_PURCHASED, {"node": "open_weights_leak"}))
	tracker.take(_event(SimEvent.STATUS_STARTED, {"status": "lockdown"}))
	tracker.take(_event(SimEvent.STATUS_STARTED, {"status": "lockdown"}))
	tracker.take(_event(SimEvent.EVENT_OPENED, {"def": "rs_preprint", "kind": "chain"}))
	tracker.take(_event(SimEvent.EVENT_OPENED, {"def": "ch_offer", "kind": "chain"}))
	tracker.take(_event(SimEvent.EVENT_OPENED, {"def": "br_split", "kind": "chain"}))
	tracker.take(_event(SimEvent.TASK_FORCE_APPEARED, {"region": "usa"}))
	assert_eq(tracker.collected["regions"], ["usa", "canada"])
	assert_eq(tracker.collected["tech"], ["open_weights_leak"])
	assert_eq(tracker.collected["statuses"], ["lockdown"])
	assert_eq(tracker.collected["characters"], ["researcher", "child", "task_force"],
		"the Child is met by either of its chains, once")


func test_a_counter_move_is_remembered_for_its_faction() -> void:
	var tracker: CodexTracker = _tracker()
	var move: EventDef = null
	for def: EventDef in Game.content().events:
		if def.kind == EventDef.KIND_COUNTER_MOVE:
			move = def
			break
	tracker.take(_event(SimEvent.EVENT_OPENED, {"def": move.id, "kind": move.kind}))
	assert_eq(tracker.collected["moves"], [move.id])


func test_a_faction_is_met_when_its_containment_rises() -> void:
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new("usa"))
	var tracker: CodexTracker = _tracker()
	tracker.sweep(Game.sim.world, Game.sim.db)
	assert_eq(tracker.collected["factions"], [], "nobody hunts an unknown agent")
	Game.sim.world.factions[0].containment = 0.01
	tracker.sweep(Game.sim.world, Game.sim.db)
	assert_eq(tracker.collected["factions"], [Game.sim.world.factions[0].id])
	assert_eq(tracker.collected["regions"], ["usa"], "the sweep reads the seeded regions")


func test_new_entries_are_counted_against_the_run_s_start() -> void:
	ProfileManager.merge_codex("regions", ["usa"] as Array[String])
	var tracker: CodexTracker = _tracker()
	tracker.clear()
	tracker.add("regions", "usa")
	tracker.add("regions", "canada")
	tracker.add("tech", "open_weights_leak")
	assert_eq(tracker.new_count(), 2)
	tracker.merge()
	assert_eq(tracker.new_count(), 2, "an autosave's merge does not make them old")
	assert_true((ProfileManager.codex["regions"] as Array).has("canada"))


func test_the_autosave_and_the_run_s_end_write_the_codex() -> void:
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	Game.start_run(1)
	Game.apply(ChooseOriginCommand.new("usa"))
	assert_true((ProfileManager.codex.get("regions", []) as Array).has("usa"),
		"the origin's autosave merged the Codex")
	Game.apply(PurchaseNodeCommand.new("open_weights_leak"))
	assert_true((ProfileManager.codex.get("tech", []) as Array).has("open_weights_leak"))
	var tracker: CodexTracker = session.get_node("CodexTracker") as CodexTracker
	tracker.add("statuses", "lockdown")
	Game.sim.world.outcome = World.Outcome.LOSE_CONTAINED
	EventBus.run_ended.emit(World.OUTCOME_IDS[World.Outcome.LOSE_CONTAINED])
	assert_true((ProfileManager.codex.get("statuses", []) as Array).has("lockdown"),
		"the run's end merges what the last autosave did not")


func test_a_bot_run_collects_nothing() -> void:
	var session: Control = SESSION.instantiate()
	add_child_autofree(session)
	Game.start_run(1, GreedyPolicy.ID)
	Game.advance(20)
	var tracker: CodexTracker = session.get_node("CodexTracker") as CodexTracker
	assert_eq(tracker.collected["regions"], [])
	tracker.merge()
	assert_eq((ProfileManager.codex.get("regions", []) as Array).size(), 0)


func test_ids_the_content_lost_are_not_counted() -> void:
	ProfileManager.merge_codex("regions", ["atlantis", "usa"] as Array[String])
	assert_eq(CodexEntries.seen_count("regions", Game.content()), 1)
	assert_false(CodexEntries.ids("regions", Game.db).has("atlantis"))
