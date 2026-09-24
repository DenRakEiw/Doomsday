extends GutTest
## S5.P — the title's version caption (`screens-full.md` §3, G5 1/3 amendment):
## in a narrow window it covered the last button, so in compact it is the
## column's last row; in the full layout it stays in the corner.

const TITLE: PackedScene = preload("res://ui/screens/title.tscn")
const PHONE: Vector2i = Vector2i(400, 860)
const NARROW_DESKTOP: Vector2i = Vector2i(1000, 700)
const DESKTOP: Vector2i = Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 4

var _boot_seen: bool = false


func before_each() -> void:
	_boot_seen = ProfileManager.boot_seen
	SaveManager.delete(SaveManager.AUTOSAVE)


func after_each() -> void:
	ProfileManager.boot_seen = _boot_seen


func _title_in(size: Vector2i) -> Control:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	var title: Control = TITLE.instantiate() as Control
	viewport.add_child(title)
	await wait_process_frames(SETTLE_FRAMES)
	return title


func _buttons(title: Control) -> Array[Control]:
	var out: Array[Control] = []
	for node: Node in title.find_children("*", "Button", true, false):
		var button: Control = node as Control
		if button.is_visible_in_tree():
			out.append(button)
	return out


func _assert_clear_of_buttons(size: Vector2i) -> void:
	var title: Control = await _title_in(size)
	var version: Label = title.call(&"version_label") as Label
	assert_true(version.is_visible_in_tree())
	assert_false(version.text.is_empty())
	var buttons: Array[Control] = _buttons(title)
	assert_gt(buttons.size(), 0)
	for button: Control in buttons:
		assert_false(version.get_global_rect().intersects(button.get_global_rect()),
			"%s: the caption covers %s" % [str(size), button.name])
	assert_eq(version.get_parent(), title.get_node("%Buttons"),
		"the last row of the column in compact")


func test_the_caption_clears_every_button_on_a_phone() -> void:
	await _assert_clear_of_buttons(PHONE)


func test_the_caption_clears_every_button_in_a_narrow_window() -> void:
	await _assert_clear_of_buttons(NARROW_DESKTOP)


func test_the_caption_stays_in_the_corner_at_full_width() -> void:
	var title: Control = await _title_in(DESKTOP)
	var version: Label = title.call(&"version_label") as Label
	assert_eq(version.get_parent(), title.get_node("Corner"))
