extends GutTest
## S6.P3b — the mute button beside the menu button (the user, 2026-09-25): a
## click through the game's own main scene mutes all sound and a second brings
## it back, the volumes untouched; the setting is stored with the others; a
## phone's strip carries the same button.
##
## `Settings.persist` is off for the test, so no click writes the player's file.

const MAIN: PackedScene = preload("res://game/main.tscn")
const SEED: int = 7
const ORIGIN: String = "france"
const WINDOW_FHD: Vector2i = Vector2i(1920, 1080)

var _window_size: Vector2i = Vector2i.ZERO
var _gut_layer: CanvasLayer = null
var _tutorial: bool = true
var _hints: bool = true
var _reduced_motion: bool = false
var _boot_seen: bool = false
var _muted: bool = false
var _persist: bool = true
var _volumes: Dictionary[String, float] = {}


func before_each() -> void:
	_tutorial = Settings.tutorial
	_hints = Settings.hints
	_reduced_motion = Settings.reduced_motion
	_boot_seen = ProfileManager.boot_seen
	_muted = Settings.muted
	_persist = Settings.persist
	_volumes = Settings.volumes.duplicate()
	Settings.persist = false
	Settings.reduced_motion = true
	Settings.muted = false
	Game.stop_run()
	Game.debug_log = false
	_window_size = get_window().size
	_gut_layer = get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if _gut_layer != null:
		_gut_layer.visible = false


func after_each() -> void:
	if _gut_layer != null:
		_gut_layer.visible = true
	get_window().size = _window_size
	ScreenRouter.slot = null
	Settings.tutorial = _tutorial
	Settings.hints = _hints
	Settings.reduced_motion = _reduced_motion
	Settings.set_muted(_muted)
	Settings.volumes = _volumes
	Settings.persist = _persist
	ProfileManager.boot_seen = _boot_seen
	Game.stop_run()


func _start_game(window: Vector2i) -> Node:
	Settings.tutorial = false
	Settings.hints = false
	get_window().size = window
	add_child_autofree(MAIN.instantiate())
	await wait_process_frames(2)
	ScreenRouter.start_new_run(null, SEED)
	Game.set_speed(0)
	await wait_process_frames(2)
	Game.site_confirm(ORIGIN)
	Game.set_speed(0)
	await wait_process_frames(4)
	return ScreenRouter.screen_node()


func _push(event: InputEvent, at: Vector2) -> void:
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		var window_at: Vector2 = get_viewport().get_final_transform() * at
		mouse.position = window_at
		mouse.global_position = window_at
	get_viewport().push_input(event)


func _click_control(control: Control) -> String:
	var at: Vector2 = control.get_global_rect().get_center()
	_push(InputEventMouseMotion.new(), at)
	await wait_process_frames(1)
	var over: Control = get_viewport().gui_get_hovered_control()
	for pressed: bool in [true, false]:
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_push(button, at)
		await wait_process_frames(1)
	if over == null:
		return "nothing under %s" % at
	if over != control and not control.is_ancestor_of(over):
		return "the pointer at %s was taken by %s" % [at, over.get_path()]
	return ""


func _master_muted() -> bool:
	return AudioServer.is_bus_mute(Audio.bus_index(AudioSheet.BUS_MASTER))


func test_the_setting_is_stored_and_read_back() -> void:
	var defaults: Dictionary = Settings.values_from({}, "en")
	assert_false(bool(defaults[Settings.KEY_MUTED]), "sound is on by default")
	var stored: Dictionary = Settings.values_from({Settings.KEY_MUTED: true}, "en")
	assert_true(bool(stored[Settings.KEY_MUTED]), "a stored mute is read back")
	Settings.muted = true
	assert_true(bool(Settings.to_dict()[Settings.KEY_MUTED]), "and written")


func test_a_click_mutes_everything_and_a_second_brings_it_back() -> void:
	var session: Node = await _start_game(WINDOW_FHD)
	var button: MuteButton = session.find_child("MuteButton", true, false) as MuteButton
	assert_not_null(button, "the top bar has the button")
	assert_true(button.is_visible_in_tree(), "it shows on a desktop")
	var volume: float = Audio.volume(AudioSheet.BUS_MASTER)
	assert_eq(button.glyph, Glyphs.Glyph.SOUND_ON)
	assert_eq(await _click_control(button), "", "the click reached the button")
	await wait_process_frames(2)
	assert_true(Settings.muted, "the click muted")
	assert_true(_master_muted(), "the master bus is silent")
	assert_eq(button.glyph, Glyphs.Glyph.SOUND_OFF, "the glyph says so")
	assert_eq(button.tooltip_key, MuteButton.KEY_UNMUTE, "and the tooltip names the way back")
	assert_eq(Audio.volume(AudioSheet.BUS_MASTER), volume, "the volume is untouched")
	assert_eq(await _click_control(button), "", "the second click reached it")
	await wait_process_frames(2)
	assert_false(Settings.muted, "sound is back")
	assert_eq(_master_muted(), volume <= 0.0, "the master bus plays at its volume again")


## The HUD switches on the viewport's width, which a headless run cannot change
## (its content scale keeps 1920 logical pixels) — so the test drives the switch
## the way the resize would, as `test_status_strip.gd` does.
func test_a_phone_strip_carries_the_button() -> void:
	var session: Node = await _start_game(WINDOW_FHD)
	var hud: Node = session.get_node("HudLayer/SafeArea/Hud")
	hud.set(&"_has_layout", false)
	hud.call(&"_apply_layout_for", true)
	await wait_process_frames(3)
	var strip: Control = session.find_child("StatusStrip", true, false) as Control
	assert_not_null(strip)
	var button: MuteButton = strip.find_child("StripMute", true, false) as MuteButton
	assert_true(button.is_visible_in_tree(), "the phone strip shows the button")
	var view: Rect2 = get_viewport().get_visible_rect()
	assert_true(view.encloses(button.get_global_rect()), "on the screen")
	assert_eq(await _click_control(button), "", "the click reached it")
	await wait_process_frames(2)
	assert_true(Settings.muted, "the phone's button mutes too")
