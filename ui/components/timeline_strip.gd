class_name TimelineStrip
extends Control
## The run's beats over the charts (analysis.md §7): a thin strip that shares the
## charts' x mapping, so a mark stands over the same day on every chart below.
##
## Marks fall into 12 px slots; a slot shows its highest-priority glyph and a dot
## when it holds more than one. Hover or focus shows every entry in the slot;
## a click or `Enter` asks the tab to put its cursor on that day.

signal day_pressed(day: int)

const TYPE_CAPTION: StringName = &"LabelCaption"
const TYPE_TOOLTIP: StringName = &"MapTooltip"
const FONT: StringName = &"font"
const FONT_SIZE: StringName = &"font_size"
const STYLE_PANEL: StringName = &"panel"
const KEY_TIP: String = "UI_ANALYSIS_STRIP_TIP"
const GLYPH: float = 16.0
const DOT_R: float = 2.0
const JOIN: String = " · "
const HAIRLINE: float = 1.0
const TIP_GAP: float = 4.0

var _day_max: int = UiTokens.MIN_SPAN_DAYS
var _marks: Array[Dictionary] = []
var _bands: Array[Dictionary] = []
## The slot under the pointer or the keyboard, −1 for none.
var _hovered: int = -1


func _ready() -> void:
	custom_minimum_size.y = float(UiTokens.STRIP_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func set_domain(day_max: int) -> void:
	_day_max = maxi(1, day_max)
	queue_redraw()


## `[{"day", "glyph", "color", "priority", "text"}]`.
func set_marks(marks: Array[Dictionary]) -> void:
	_marks = marks
	queue_redraw()


## The phase bands; drawn as boundary hairlines only.
func set_bands(bands: Array[Dictionary]) -> void:
	_bands = bands
	queue_redraw()


## Slot index → its marks, highest priority first (ties: earlier day).
func slots() -> Dictionary[int, Array]:
	var out: Dictionary[int, Array] = {}
	for mark: Dictionary in _marks:
		var slot: int = _slot_of(float(mark["day"]))
		if not out.has(slot):
			out[slot] = []
		out[slot].append(mark)
	for slot: int in out:
		var list: Array = out[slot]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["priority"]) != int(b["priority"]):
				return int(a["priority"]) > int(b["priority"])
			return int(a["day"]) < int(b["day"]))
	return out


## The line the tooltip shows for a slot: its first day and every entry.
func tip_for(slot: int) -> String:
	var list: Array = slots().get(slot, [])
	if list.is_empty():
		return ""
	var first: int = int(list[0]["day"])
	var texts: PackedStringArray = PackedStringArray()
	for mark: Dictionary in list:
		first = mini(first, int(mark["day"]))
		texts.append(str(mark.get("text", "")))
	return tr(KEY_TIP).format({"day": Format.number(float(first), Format.Kind.DAYS),
		"entries": JOIN.join(texts)})


## Presses a slot as a click would: `day_pressed` with its top mark's day.
func press_slot(slot: int) -> void:
	var list: Array = slots().get(slot, [])
	if not list.is_empty():
		day_pressed.emit(int(list[0]["day"]))


func _plot_left() -> float:
	return UiTokens.CHART_AXIS_W


func _plot_width() -> float:
	return maxf(1.0, size.x - UiTokens.CHART_AXIS_W - UiTokens.CHART_LABEL_W)


func _day_to_x(day: float) -> float:
	return _plot_left() + day / float(_day_max) * _plot_width()


func _slot_of(day: float) -> int:
	return floori((_day_to_x(day) - _plot_left()) / UiTokens.STRIP_SLOT)


func _slot_centre(slot: int) -> float:
	return _plot_left() + (float(slot) + 0.5) * UiTokens.STRIP_SLOT


func _draw() -> void:
	var mid: float = size.y * 0.5
	for i: int in range(1, _bands.size()):
		var x: float = _day_to_x(float(_bands[i]["from"]))
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), UiTokens.color(&"LINE_1"), HAIRLINE)
	var all: Dictionary[int, Array] = slots()
	for slot: int in all:
		var list: Array = all[slot]
		var top: Dictionary = list[0]
		var box: Rect2 = Rect2(_slot_centre(slot) - GLYPH * 0.5, mid - GLYPH * 0.5, GLYPH, GLYPH)
		var scale_factor: float = GLYPH / GlyphIcon.AUTHORED_BOX
		draw_set_transform(box.position, 0.0, Vector2(scale_factor, scale_factor))
		Glyphs.draw(self, top["glyph"], Rect2(Vector2.ZERO, Vector2.ONE * GlyphIcon.AUTHORED_BOX),
			top["color"], UiTokens.GLYPH_STROKE)
		draw_set_transform(Vector2.ZERO)
		if list.size() > 1:
			draw_circle(Vector2(_slot_centre(slot), box.end.y + DOT_R), DOT_R,
				UiTokens.color(&"TEXT_2"))
	if _hovered >= 0 and all.has(_hovered):
		_draw_tip(tip_for(_hovered))


func _draw_tip(text: String) -> void:
	var box: StyleBox = get_theme_stylebox(STYLE_PANEL, TYPE_TOOLTIP)
	var font: Font = get_theme_font(FONT, TYPE_CAPTION)
	var font_size: int = get_theme_font_size(FONT_SIZE, TYPE_CAPTION)
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) \
		+ Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
			box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))
	var left: float = clampf(_slot_centre(_hovered) + TIP_GAP, 0.0, maxf(0.0, size.x - extent.x))
	var rect: Rect2 = Rect2(Vector2(left, 0.0), extent)
	draw_style_box(box, rect)
	draw_string(font, rect.position + Vector2(box.get_margin(SIDE_LEFT),
		box.get_margin(SIDE_TOP) + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, UiTokens.color(&"TEXT_0"))


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_hover(_slot_near(motion.position.x))
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var slot: int = _slot_near(button.position.x)
		if slot >= 0:
			press_slot(slot)
			accept_event()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	var ordered: Array = slots().keys()
	ordered.sort()
	if ordered.is_empty():
		return
	var at: int = ordered.find(_hovered)
	match key.keycode:
		KEY_LEFT:
			_hover(int(ordered[maxi(0, at - 1)]) if at >= 0 else int(ordered[ordered.size() - 1]))
		KEY_RIGHT:
			_hover(int(ordered[mini(ordered.size() - 1, at + 1)]) if at >= 0 else int(ordered[0]))
		KEY_ENTER, KEY_KP_ENTER:
			if _hovered >= 0:
				press_slot(_hovered)
		_:
			return
	accept_event()


## The slot under `x`, or the nearest one with marks within a touch target's
## half width; −1 when there is none.
func _slot_near(x: float) -> int:
	var best: int = -1
	var best_distance: float = float(UiTokens.HIT_MIN) * 0.5
	for slot: int in slots():
		var distance: float = absf(_slot_centre(slot) - x)
		if distance <= best_distance:
			best_distance = distance
			best = slot
	return best


func _hover(slot: int) -> void:
	if slot == _hovered:
		return
	_hovered = slot
	# The tip is drawn, not a `tooltip_text`: a keyboard reader moving slot to
	# slot sees it too. The accessible text follows it.
	accessibility_description = tip_for(slot) if slot >= 0 else ""
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover(-1)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
