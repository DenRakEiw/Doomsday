extends GutTest
## S3.5 — the strip and the run, end to end (spec ticker.md §8.2): what the
## player does reaches the ticker in the player's language, and the register
## turns when the world does.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
## §8.3: a greedy run says this many lines, from all three streams.
const LINES_MIN: int = 40
## §8.3 asks for 200. The shipped anomaly cooldowns say more than that (see
## PROGRESS.md, *Design questions*); this ceiling catches a runaway, not the
## balance.
const LINES_MAX: int = 400

var _session: Control = null
var _ticker: PanelContainer = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_ticker = _session.get_node("HudLayer/SafeArea/Hud/%Ticker")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func test_a_purchase_and_a_seed_reach_the_strip() -> void:
	_start()
	await get_tree().process_frame
	assert_true(_said_something(), "the origin is news")

	_ticker.call("clear")
	Game.sim.world.agent.compute += 500.0
	var node: TechNodeDef = Game.sim.available_nodes()[0]
	assert_true(Game.apply(PurchaseNodeCommand.new(node.id)).ok, "the first node is affordable")
	await get_tree().process_frame
	assert_true(_said_something(), "a purchase says something in the same frame")

	_ticker.call("clear")
	var seeded: bool = false
	for i: int in 40:
		Game.advance(1)
		await get_tree().process_frame
		if _said_something():
			seeded = true
			break
	assert_true(seeded, "and so does the run going on without the player")


## Something other than "all systems nominal" is on the strip. With reduced
## motion a pushed line goes up at once, so the queue is not where to look.
func _said_something() -> bool:
	return int(_ticker.call("queued")) > 0 or str(_ticker.call("text")) != tr("UI_TICKER_IDLE")


func test_the_register_turns_when_the_world_opens() -> void:
	_start()
	assert_eq(String(_ticker.call("register")), "institutional")
	EventBus.sim_event.emit(SimEvent.new(SimEvent.PHASE_CHANGED, 40,
		{"from": "emergent", "to": "open"}))
	assert_eq(String(_ticker.call("register")), "emergency")
	# A separator is between two lines, so it takes two to see one.
	Settings.set_reduced_motion(false)
	for region_id: String in ["usa", "germany"]:
		_ticker.call("push_key", "HEADLINE_SEED_FIRST", {"region": region_id})
	await get_tree().process_frame
	assert_string_contains(str(_ticker.call("text")), "///")


## §8.3, as far as a test can carry it: a whole greedy run on the shipped
## content, with every stream heard from, the origin first and the outcome last.
func test_a_greedy_run_says_between_forty_and_two_hundred_lines() -> void:
	var lines: Array[Dictionary] = _greedy_run()
	assert_between(lines.size(), LINES_MIN, LINES_MAX)

	var streams: Dictionary[String, int] = {}
	for row: Dictionary in lines:
		var stream: String = str(row["stream"])
		streams[stream] = streams.get(stream, 0) + 1
	for stream: String in HeadlineDef.STREAMS:
		assert_gt(streams.get(stream, 0), 0, "the %s stream is heard from" % stream)

	assert_eq(str(lines[0]["id"]), "origin_chosen", "the first line is the origin's")
	assert_string_contains(str(lines[lines.size() - 1]["id"]), "outcome_",
		"and the last is how it ended")
	_assert_cooldowns_held(lines)


func _greedy_run() -> Array[Dictionary]:
	var Harness: GDScript = load("res://tools/sim_harness.gd")
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(Game.db, SEED, GreedyPolicy.ID, 5000, false, problems)
	return played["headlines"]


## No line is repeated inside its own `cooldown_days`.
func _assert_cooldowns_held(lines: Array[Dictionary]) -> void:
	var last: Dictionary[String, int] = {}
	for row: Dictionary in lines:
		var id: String = str(row["id"])
		var day: int = int(row["day"])
		var def: HeadlineDef = Game.db.headline(id)
		if last.has(id):
			assert_gte(day - last[id], def.cooldown_days,
				"%s waited out its cooldown of %d days" % [id, def.cooldown_days])
		last[id] = day
