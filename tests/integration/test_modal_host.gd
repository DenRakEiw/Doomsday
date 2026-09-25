extends GutTest
## S6.7 — `ModalHost.open_over` (first-run.md §6.8): one level of stacking, for
## help over whatever modal is up.

var _host: ModalHost = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	_host = ModalHost.new()
	add_child_autofree(_host)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion


## A modal with one button to take the focus.
func _modal(modal_name: String) -> Control:
	var modal: Control = Control.new()
	modal.name = modal_name
	modal.visible = false
	var button: Button = Button.new()
	button.text = modal_name
	modal.add_child(button)
	_host.add_child(modal)
	return modal


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_over_nothing_it_is_an_ordinary_open() -> void:
	var help: Control = _modal("Help")
	_host.open_over(help)
	assert_eq(_host.current(), help)
	assert_null(_host.below())
	assert_true(_host.visible)
	_host.close()
	assert_false(_host.is_open())
	assert_false(_host.visible, "nothing below: the host goes")


func test_over_an_open_modal_both_show_and_the_top_has_the_focus() -> void:
	var tree: Control = _modal("Tree")
	var help: Control = _modal("Help")
	_host.open(tree)
	_host.open_over(help)
	assert_eq(_host.current(), help)
	assert_eq(_host.below(), tree)
	assert_true(tree.visible, "the one below stays on screen")
	assert_true(help.visible)
	assert_gt(help.get_index(), tree.get_index(), "drawn above it")
	assert_true(help.is_ancestor_of(_focus()))


func test_closing_the_top_returns_to_the_one_below() -> void:
	var tree: Control = _modal("Tree")
	var help: Control = _modal("Help")
	_host.open(tree)
	_host.open_over(help)
	_host.close()
	assert_eq(_host.current(), tree)
	assert_null(_host.below())
	assert_false(help.visible)
	assert_true(tree.visible)
	assert_true(_host.visible, "the scrim stays")
	assert_true(tree.is_ancestor_of(_focus()), "its focus comes back")


func test_the_queue_waits_until_nothing_is_below() -> void:
	var tree: Control = _modal("Tree")
	var help: Control = _modal("Help")
	var discovery: Control = _modal("Discovery")
	_host.open(tree)
	_host.open_over(help)
	_host.open(discovery)
	assert_eq(_host.current(), help, "a third modal queues")
	_host.close()
	assert_eq(_host.current(), tree, "the one below first, not the queue")
	assert_false(discovery.visible)
	_host.close()
	assert_eq(_host.current(), discovery)


func test_escape_closes_only_the_top() -> void:
	var tree: Control = _modal("Tree")
	var help: Control = _modal("Help")
	_host.open(tree)
	_host.open_over(help)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_host.call(&"_unhandled_key_input", key)
	assert_eq(_host.current(), tree)
	assert_true(tree.visible)
