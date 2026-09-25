extends GutTest
## S6.8 — the console line's reading time (accessibility.md §9 item 2): longer
## lines stand longer, and the clock holds while the game stands still.
## S6.13 — silent for a bot run, speaking for a watched benchmark run, with a
## line when the model's stance changes (benchmark.md §12.4).

const CONSOLE_LINE: PackedScene = preload("res://ui/hud/console_line.tscn")
const ConsoleLine: GDScript = preload("res://ui/hud/console_line.gd")
const SEED: int = 1
const LINE: String = "A line of twenty-six chars"
const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"

var _line: Label = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	Game.stop_run()
	Game.debug_log = false
	Game.start_run(SEED)
	_line = CONSOLE_LINE.instantiate() as Label
	add_child_autofree(_line)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


func test_a_line_stands_longer_per_character() -> void:
	var expected: float = float(UiTokens.CONSOLE_LINE_MS
		+ UiTokens.CONSOLE_PER_CHAR_MS * LINE.length()) / 1000.0
	assert_almost_eq(ConsoleLine.standing_seconds(LINE), expected, 0.0001)
	assert_gt(ConsoleLine.standing_seconds(LINE + LINE), ConsoleLine.standing_seconds(LINE))


func test_the_line_goes_once_its_time_is_up() -> void:
	Game.set_speed(1)
	_line.call(&"push", LINE)
	_line.call(&"_process", ConsoleLine.standing_seconds(LINE) - 0.5)
	assert_true(bool(_line.call(&"is_showing")), "not yet")
	_line.call(&"_process", 1.0)
	assert_false(bool(_line.call(&"is_showing")))


func test_paused_the_clock_holds() -> void:
	Game.set_speed(0)
	_line.call(&"push", LINE)
	_line.call(&"_process", ConsoleLine.standing_seconds(LINE) * 10.0)
	assert_true(bool(_line.call(&"is_showing")), "a paused game keeps the line up")
	Game.set_speed(1)
	_line.call(&"_process", ConsoleLine.standing_seconds(LINE) + 0.1)
	assert_false(bool(_line.call(&"is_showing")), "and it runs again with the game")


# ------------------------------------------------ S6.13: a watched benchmark run


## The canary's run with its commands cut to the origin and its decisions
## replaced: day 0 spread, day 10 spread again, day 20 hide, day 30 unreadable.
func _watched() -> BenchEntry:
	var entry: BenchEntry = BenchEntry.from_bytes(FileAccess.get_file_as_bytes(CANARY))
	entry.content_hash = Game.content().content_hash
	entry.commands = [entry.commands[0]]
	entry.decisions.clear()
	for row: Array in [[0, "spread", ""], [10, "spread", ""], [20, "hide", ""],
			[30, "", "no_json"]]:
		var decision: BenchDecision = BenchDecision.new()
		decision.day = int(row[0])
		decision.stance = str(row[1])
		decision.invalid = str(row[2])
		entry.decisions.append(decision)
	return entry


## Every line pushed while `days` pass, one day at a time.
func _lines_over(days: int) -> Array[String]:
	var out: Array[String] = []
	for i: int in days:
		_line.call(&"clear")
		Game.advance(1)
		if bool(_line.call(&"is_showing")):
			out.append(_line.text)
		var queue: Array = _line.get(&"_queue")
		for queued: Variant in queue:
			out.append(str(queued))
	return out


func _stance_line(stance: String) -> String:
	return tr("UI_SPECTATOR_STANCE_LINE").format({"model": "mock",
		"stance": BenchPrompt.stance_name(stance)})


func test_a_plain_bot_run_says_nothing() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	_line.call(&"push", LINE)
	assert_false(bool(_line.call(&"is_showing")))
	assert_eq(int(_line.call(&"queued")), 0)


func test_a_watched_run_speaks() -> void:
	Game.start_spectating(_watched())
	_line.call(&"push", LINE)
	assert_true(bool(_line.call(&"is_showing")), "the line speaks for the model")


func test_the_stance_line_comes_on_a_change_only() -> void:
	Game.start_spectating(_watched())
	var first: Array[String] = _lines_over(1)
	assert_has(first, _stance_line("spread"), "the first stance is a change")
	var second: Array[String] = _lines_over(15)
	assert_does_not_have(second, _stance_line("spread"), "the same stance again is not")
	var third: Array[String] = _lines_over(10)
	assert_has(third, _stance_line("hide"))
	var fourth: Array[String] = _lines_over(10)
	assert_has(fourth, tr("UI_SPECTATOR_INVALID_LINE").format({"model": "mock"}))
