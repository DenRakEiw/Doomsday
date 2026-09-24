extends GutTest
## S4.P — `ButtonContent`: a button grows with the laid-out child it carries.

var _root: Control = null


func before_each() -> void:
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	add_child_autofree(_root)


func _button_with_column(lines: int) -> Array[Control]:
	var button: Button = Button.new()
	var column: VBoxContainer = VBoxContainer.new()
	for i: int in lines:
		var label: Label = Label.new()
		label.text = "line %d" % i
		column.add_child(label)
	button.add_child(column)
	_root.add_child(button)
	return [button, column] as Array[Control]


func test_the_button_is_at_least_as_tall_as_its_content() -> void:
	var parts: Array[Control] = _button_with_column(4)
	ButtonContent.fit(parts[0] as Button, parts[1], false, true)
	var wanted: float = parts[1].get_combined_minimum_size().y
	assert_gt(wanted, float(UiTokens.HIT_MIN), "four lines are taller than a hit target")
	assert_eq(parts[0].custom_minimum_size.y, wanted)


func test_the_button_never_drops_below_the_hit_target() -> void:
	var parts: Array[Control] = _button_with_column(1)
	ButtonContent.fit(parts[0] as Button, parts[1], false, true)
	assert_eq(parts[0].custom_minimum_size.y, float(UiTokens.HIT_MIN))


func test_the_button_follows_its_content_when_it_grows() -> void:
	var parts: Array[Control] = _button_with_column(1)
	ButtonContent.fit(parts[0] as Button, parts[1], true, true)
	for i: int in 4:
		var label: Label = Label.new()
		label.text = "a much longer line than the first %d" % i
		parts[1].add_child(label)
	# A container reports its new minimum at the end of the frame.
	await wait_process_frames(2)
	assert_eq(parts[0].custom_minimum_size, Vector2(parts[1].get_combined_minimum_size().x,
		parts[1].get_combined_minimum_size().y))
