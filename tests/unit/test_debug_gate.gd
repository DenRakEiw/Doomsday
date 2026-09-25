extends GutTest
## S6.10 — release.md §7: `Game.debug_allowed` is the one gate for the debug keys
## and the development switches. False (a release build): F5 starts no run, L, K
## and M change no setting, `--pseudo` is ignored. True: they work.
##
## Nothing reaches the player's settings file: `Settings.persist` is off for the
## whole test and every value is put back.

var _allowed: bool = true
var _locale: String = ""
var _text_scale: float = 1.0
var _reduced_motion: bool = false


func before_each() -> void:
	_allowed = Game.debug_allowed
	_locale = Settings.locale
	_text_scale = Settings.text_scale
	_reduced_motion = Settings.reduced_motion
	Settings.persist = false
	Game.stop_run()


func after_each() -> void:
	Game.debug_allowed = _allowed
	Game.stop_run()
	Game.debug_log = false
	Settings.set_pseudo_locale(false)
	Settings.set_locale(_locale)
	Settings.set_text_scale(_text_scale)
	Settings.set_reduced_motion(_reduced_motion)
	Settings.persist = true


func test_a_release_build_starts_no_bot_run_on_f5() -> void:
	Game.debug_allowed = false
	_press(KEY_F5)
	assert_null(Game.sim)


func test_a_debug_build_starts_a_bot_run_on_f5() -> void:
	Game.debug_allowed = true
	_press(KEY_F5)
	assert_not_null(Game.sim)
	assert_not_null(Game.policy)


func test_a_release_build_changes_no_setting_on_l_k_m() -> void:
	Game.debug_allowed = false
	_press(KEY_L)
	_press(KEY_K)
	_press(KEY_M)
	assert_eq(Settings.locale, _locale)
	assert_eq(Settings.text_scale, _text_scale)
	assert_eq(Settings.reduced_motion, _reduced_motion)


func test_a_debug_build_changes_the_settings_on_l_k_m() -> void:
	Game.debug_allowed = true
	_press(KEY_L)
	_press(KEY_K)
	_press(KEY_M)
	assert_ne(Settings.locale, _locale)
	assert_ne(Settings.text_scale, _text_scale)
	assert_ne(Settings.reduced_motion, _reduced_motion)


func test_a_release_build_ignores_pseudo() -> void:
	Game.debug_allowed = false
	Settings.apply_args(PackedStringArray(["--pseudo"]))
	assert_false(Settings.pseudo_locale)


func test_a_debug_build_takes_pseudo() -> void:
	Game.debug_allowed = true
	Settings.apply_args(PackedStringArray(["--pseudo"]))
	assert_true(Settings.pseudo_locale)


func test_the_gate_follows_the_build_by_default() -> void:
	# The tests run in a debug build (the editor binary), so the gate is open.
	assert_eq(_allowed, OS.is_debug_build())


func _press(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Game._unhandled_key_input(event)
