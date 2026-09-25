extends GutTest
## S6.8 — the console line's reading time (accessibility.md §9 item 2): longer
## lines stand longer, and the clock holds while the game stands still.

const CONSOLE_LINE: PackedScene = preload("res://ui/hud/console_line.tscn")
const ConsoleLine: GDScript = preload("res://ui/hud/console_line.gd")
const SEED: int = 1
const LINE: String = "A line of twenty-six chars"

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
