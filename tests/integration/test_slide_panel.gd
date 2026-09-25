extends GutTest
## S6.8 — a panel opened from the keyboard takes the focus and gives it back
## (accessibility.md §4.4).

var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = true


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion


func _panel() -> SlidePanel:
	var panel: SlidePanel = SlidePanel.new()
	var body: VBoxContainer = VBoxContainer.new()
	var button: Button = Button.new()
	button.name = "First"
	body.add_child(button)
	panel.add_child(body)
	add_child_autofree(panel)
	return panel


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_take_focus_grabs_the_primary_and_close_gives_it_back() -> void:
	var opener: Button = Button.new()
	add_child_autofree(opener)
	opener.grab_focus()
	var panel: SlidePanel = _panel()
	panel.open(true)
	assert_eq(_focus(), panel.primary_focus())
	assert_eq(_focus().name, "First")
	panel.close()
	assert_eq(_focus(), opener)


func test_without_take_focus_the_focus_stays() -> void:
	var opener: Button = Button.new()
	add_child_autofree(opener)
	opener.grab_focus()
	var panel: SlidePanel = _panel()
	panel.open()
	assert_eq(_focus(), opener)


func test_an_opener_that_is_gone_hands_the_focus_to_the_fallback() -> void:
	var opener: Button = Button.new()
	add_child(opener)
	opener.grab_focus()
	var fallback: Button = Button.new()
	add_child_autofree(fallback)
	var panel: SlidePanel = _panel()
	panel.focus_fallback = fallback
	panel.open(true)
	opener.free()
	panel.close()
	assert_eq(_focus(), fallback)
