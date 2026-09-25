extends GutTest
## S6.P1 — where the coach card sits while a modal is up (D6.8, first-run.md
## §6.4): on a wide screen at the bottom left, clear of the centred modal; on a
## phone at the top edge, under the safe area — a wire card's answers are at the
## bottom. Back at the bottom centre when the modal closes. The session runs in
## a viewport of its own, because the layout follows the viewport it is in.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 7
const PHONE: Vector2i = Vector2i(400, 860)
const DESKTOP: Vector2i = Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 3

var _session: Node = null
var _coach: Control = null
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
	Game.stop_run()


func after_each() -> void:
	Settings.tutorial = _tutorial
	Settings.hints = _hints
	Settings.reduced_motion = _reduced_motion
	Game.stop_run()


## A player's run on the origin step: the card is up from the start.
func _session_in(size: Vector2i) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	_session = SESSION.instantiate()
	viewport.add_child(_session)
	_coach = _session.get_node("%Coach") as Control
	Game.start_run(SEED)
	Game.set_speed(0)
	await wait_process_frames(SETTLE_FRAMES)


func _open_menu() -> void:
	_session.call(&"_open_pause_menu")
	await wait_process_frames(SETTLE_FRAMES)


func _close_menu() -> void:
	_session.call(&"_on_pause_closed")
	await wait_process_frames(SETTLE_FRAMES)


func test_on_a_phone_the_card_goes_to_the_top_edge_over_a_modal() -> void:
	await _session_in(PHONE)
	assert_true(_coach.visible, "the origin step's card is up")
	var bottom_y: float = _coach.position.y
	# Without a modal it sits above the phone's HUD, well down from the top.
	assert_gt(bottom_y, float(UiTokens.GUTTER) * 4.0, "not at the top without a modal")

	await _open_menu()
	assert_true(_coach.visible)
	assert_almost_eq(_coach.position.y, float(UiTokens.GUTTER), 0.5,
		"at the top edge, under the safe area (none on a desktop build)")

	await _close_menu()
	assert_almost_eq(_coach.position.y, bottom_y, 0.5, "back at its place")


func test_on_a_wide_screen_the_card_goes_to_the_bottom_left_over_a_modal() -> void:
	await _session_in(DESKTOP)
	var centred_x: float = _coach.position.x
	assert_gt(centred_x, float(UiTokens.GUTTER), "centred without a modal")

	await _open_menu()
	assert_almost_eq(_coach.position.x, float(UiTokens.GUTTER), 0.5)
	assert_gt(_coach.position.y, float(DESKTOP.y) * 0.5, "still at the bottom")

	await _close_menu()
	assert_almost_eq(_coach.position.x, centred_x, 0.5)
