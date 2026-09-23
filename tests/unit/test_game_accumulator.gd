extends GutTest
## The fixed-step accumulator of ui-foundation.md §10.3. `ticks_for` is static, so
## none of this needs the autoload, a frame or a simulation.

const GameScript := preload("res://game/autoload/game.gd")

const FRAME: float = 1.0 / 60.0
## One day is two seconds at 1× since G3, so a whole tick is 120 frames.
const FRAMES_PER_DAY: int = 120


## Runs `count` frames of `delta` and returns [ticks, accumulator].
func _run(delta: float, speed: int, count: int) -> Array:
	var accumulator: float = 0.0
	var ticks: int = 0
	for i: int in count:
		var step: Array = GameScript.ticks_for(delta, speed, accumulator)
		ticks += int(step[0])
		accumulator = float(step[1])
	return [ticks, accumulator]


func test_two_seconds_at_normal_speed_is_one_tick() -> void:
	var result: Array = _run(FRAME, 1, FRAMES_PER_DAY)
	assert_eq(int(result[0]), 1, "one day every two seconds at 1x")


func test_two_seconds_at_quadruple_speed_is_four_ticks() -> void:
	var result: Array = _run(FRAME, 4, FRAMES_PER_DAY)
	assert_eq(int(result[0]), 4, "four days in two seconds at 4x")


func test_two_seconds_at_double_speed_is_two_ticks() -> void:
	var result: Array = _run(FRAME, 2, FRAMES_PER_DAY)
	assert_eq(int(result[0]), 2, "two days in two seconds at 2x")


func test_paused_yields_no_ticks() -> void:
	var result: Array = _run(FRAME, 0, FRAMES_PER_DAY * 10)
	assert_eq(int(result[0]), 0, "a paused game never advances")


func test_pause_does_not_bank_time() -> void:
	var paused: Array = GameScript.ticks_for(10.0, 0, 0.0)
	assert_eq(float(paused[1]), 0.0, "the accumulator stands still while paused")


func test_a_long_frame_is_capped_and_the_rest_dropped() -> void:
	var step: Array = GameScript.ticks_for(10.0, 4, 0.0)
	assert_eq(int(step[0]), GameScript.MAX_TICKS_PER_FRAME, "the cap holds")
	assert_eq(float(step[1]), 0.0, "the backlog is dropped, not carried")


func test_a_frame_shorter_than_a_tick_carries_the_remainder() -> void:
	var step: Array = GameScript.ticks_for(FRAME, 1, 0.0)
	assert_eq(int(step[0]), 0, "a hundred and twentieth of a day is no day")
	assert_almost_eq(float(step[1]), FRAME, 1e-9, "and it is kept for the next frame")


func test_the_remainder_below_the_cap_survives() -> void:
	# Exactly two ticks' worth plus a quarter, at 2x: one second per tick.
	var step: Array = GameScript.ticks_for(2.25, 2, 0.0)
	assert_eq(int(step[0]), 2, "two whole ticks")
	assert_almost_eq(float(step[1]), 0.25, 1e-9, "the quarter tick is carried")
