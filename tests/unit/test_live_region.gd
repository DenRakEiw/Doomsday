extends GutTest
## S6.8 — the line a screen reader speaks (accessibility.md §3.4). No reader runs
## under the test runner, so the spoken cases set `force_active`.

const NBSP: String = " "


func _region() -> LiveRegion:
	var region: LiveRegion = LiveRegion.new()
	add_child_autofree(region)
	return region


func test_without_a_reader_nothing_is_written() -> void:
	var region: LiveRegion = _region()
	region.say("hello")
	assert_eq(region.text, "")


func test_forced_the_text_is_set() -> void:
	var region: LiveRegion = _region()
	region.force_active = true
	region.say("hello")
	assert_eq(region.text, "hello")


func test_the_same_text_twice_differs_by_a_trailing_no_break_space() -> void:
	var region: LiveRegion = _region()
	region.force_active = true
	region.say("hello")
	region.say("hello")
	assert_eq(region.text, "hello" + NBSP)
	region.say("hello")
	assert_eq(region.text, "hello", "and back, so every repeat is a change")


func test_the_live_mode_follows_assertive() -> void:
	var region: LiveRegion = _region()
	assert_eq(region.accessibility_live, AccessibilityServer.LIVE_POLITE)
	region.assertive = true
	assert_eq(region.accessibility_live, AccessibilityServer.LIVE_ASSERTIVE)


func test_it_is_drawn_invisible_and_takes_no_input() -> void:
	var region: LiveRegion = _region()
	assert_eq(region.self_modulate.a, 0.0)
	assert_eq(region.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(region.focus_mode, Control.FOCUS_NONE)
	assert_true(region.visible, "a hidden node leaves the accessibility tree")
