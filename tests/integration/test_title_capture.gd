extends GutTest
## S7.I (itch.md §8.3): the title's debug capture — `F12` writes the view,
## `Shift+F12` hides the menu and the caption for that one frame, and a release
## build leaves `F12` alone (release.md §7).

const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const TitleScript: GDScript = preload("res://ui/screens/title.gd")
const DESKTOP: Vector2i = Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 4

var _boot_seen: bool = false
var _debug_allowed: bool = false


func before_each() -> void:
	_boot_seen = ProfileManager.boot_seen
	_debug_allowed = Game.debug_allowed
	SaveManager.delete(SaveManager.AUTOSAVE)


func after_each() -> void:
	ProfileManager.boot_seen = _boot_seen
	Game.debug_allowed = _debug_allowed


func _title() -> Control:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = DESKTOP
	add_child_autofree(viewport)
	var title: Control = TITLE.instantiate() as Control
	viewport.add_child(title)
	await wait_process_frames(SETTLE_FRAMES)
	return title


func _f12(shift: bool) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F12
	key.pressed = true
	key.shift_pressed = shift
	return key


func test_shot_path_names_locale_width_and_bare() -> void:
	assert_eq(TitleScript.shot_path("en", 1920, false), "user://title_en_1920.png")
	assert_eq(TitleScript.shot_path("de", 2560, true), "user://title_de_2560_bare.png")


func test_hidden_chrome_is_transparent_and_keeps_the_globe_in_place() -> void:
	var title: Control = await _title()
	var globe: Control = title.get_node("%Globe") as Control
	var before: Rect2 = globe.get_global_rect()
	title.call(&"set_chrome_hidden", true)
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq((title.get_node("%Side") as Control).modulate.a, 0.0)
	assert_eq((title.get_node("Corner") as Control).modulate.a, 0.0)
	assert_eq(globe.get_global_rect(), before)
	title.call(&"set_chrome_hidden", false)
	assert_eq((title.get_node("%Side") as Control).modulate.a, 1.0)
	assert_eq((title.get_node("Corner") as Control).modulate.a, 1.0)


func test_capture_puts_the_chrome_back_after_its_frame() -> void:
	var title: Control = await _title()
	title.call(&"capture", true)
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq((title.get_node("%Side") as Control).modulate.a, 1.0)
	assert_eq((title.get_node("Corner") as Control).modulate.a, 1.0)


func test_f12_does_nothing_in_a_release_build() -> void:
	Game.debug_allowed = false
	var title: Control = await _title()
	title.call(&"_unhandled_key_input", _f12(true))
	assert_eq((title.get_node("%Side") as Control).modulate.a, 1.0)
	assert_false(title.get_viewport().is_input_handled())


func test_shift_f12_hides_the_chrome_in_a_debug_build() -> void:
	Game.debug_allowed = true
	var title: Control = await _title()
	title.call(&"_unhandled_key_input", _f12(true))
	assert_eq((title.get_node("%Side") as Control).modulate.a, 0.0)
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq((title.get_node("%Side") as Control).modulate.a, 1.0)
