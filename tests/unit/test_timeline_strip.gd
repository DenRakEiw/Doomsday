extends GutTest
## S4.8 — the timeline strip (analysis.md §7).

var _root: Control = null


func before_each() -> void:
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	add_child_autofree(_root)


func _strip() -> TimelineStrip:
	var strip: TimelineStrip = TimelineStrip.new()
	_root.add_child(strip)
	strip.size = Vector2(UiTokens.CHART_AXIS_W + 400.0 + UiTokens.CHART_LABEL_W, 28.0)
	strip.set_domain(400)
	strip.set_marks([
		{"day": 100, "glyph": Glyphs.Glyph.EVENT_OPENING, "color": Color.WHITE, "priority": 1,
			"text": "an opening"},
		{"day": 101, "glyph": Glyphs.Glyph.EVENT_COUNTER, "color": Color.WHITE, "priority": 4,
			"text": "discovered"},
		{"day": 300, "glyph": Glyphs.Glyph.OUTCOME, "color": Color.WHITE, "priority": 5,
			"text": "the end"},
	] as Array[Dictionary])
	return strip


func test_two_marks_in_one_slot_show_the_higher_priority_first() -> void:
	var slots: Dictionary[int, Array] = _strip().slots()
	assert_eq(slots.size(), 2)
	var crowded: Array = []
	for slot: int in slots:
		if slots[slot].size() == 2:
			crowded = slots[slot]
	assert_eq(crowded.size(), 2, "one day apart, one slot")
	assert_eq(int(crowded[0]["priority"]), 4)


func test_the_tip_lists_every_entry_of_the_slot() -> void:
	var strip: TimelineStrip = _strip()
	for slot: int in strip.slots():
		if strip.slots()[slot].size() == 2:
			var tip: String = strip.tip_for(slot)
			assert_string_contains(tip, "an opening")
			assert_string_contains(tip, "discovered")
			assert_string_contains(tip, Format.number(100.0, Format.Kind.DAYS), "the first day")


func test_pressing_a_slot_gives_the_top_marks_day() -> void:
	var strip: TimelineStrip = _strip()
	var pressed: Array[int] = []
	strip.day_pressed.connect(func(day: int) -> void: pressed.append(day))
	for slot: int in strip.slots():
		strip.press_slot(slot)
	pressed.sort()
	assert_eq(pressed, [101, 300] as Array[int])
