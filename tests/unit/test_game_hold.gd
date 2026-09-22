extends GutTest
## S3.2 — the interface holding the clock (spec m3-screens.md §10.2).
##
## The counter is what makes a pause menu over a paused tech tree give the speed
## back exactly once.

const HOLD_A: StringName = &"a"
const HOLD_B: StringName = &"b"


func before_each() -> void:
	Game.stop_run()
	Game.debug_log = false
	Game.start_run(1)


func after_each() -> void:
	Game.stop_run()


func test_nested_holds_restore_once() -> void:
	Game.set_speed(2)
	Game.hold(HOLD_A)
	assert_eq(Game.speed, 0)
	Game.hold(HOLD_B)
	Game.release(HOLD_A)
	assert_eq(Game.speed, 0, "the second reason still holds it")
	Game.release(HOLD_B)
	assert_eq(Game.speed, 2, "and the speed comes back once")


func test_a_repeated_reason_is_one_hold() -> void:
	Game.set_speed(1)
	Game.hold(HOLD_A)
	Game.hold(HOLD_A)
	Game.release(HOLD_A)
	assert_false(Game.is_held())
	assert_eq(Game.speed, 1)


func test_the_speed_keys_are_ignored_while_held() -> void:
	Game.set_speed(1)
	Game.hold(HOLD_A)
	Game.set_speed(4)
	assert_eq(Game.speed, 0, "the run stays where it is")
	Game.release(HOLD_A)
	assert_eq(Game.speed, 4, "and what was asked for is what it goes back to")


func test_releasing_an_unknown_reason_changes_nothing() -> void:
	Game.set_speed(2)
	Game.release(HOLD_B)
	assert_eq(Game.speed, 2)
	assert_false(Game.is_held())


func test_a_new_run_clears_every_hold() -> void:
	Game.hold(HOLD_A)
	Game.start_run(2)
	assert_false(Game.is_held())
