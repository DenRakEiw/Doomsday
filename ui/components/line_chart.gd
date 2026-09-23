class_name LineChart
extends Control
## A small line chart over the days of a run (analysis.md §6): one or more
## series, one y axis, thin marks, a cursor with a tooltip, and the pieces the
## Analysis sheet lays over it — the phase bands, the discovery moment, the
## threshold lines.
##
## Everything is drawn: a chart that grows by one sample a day needs no nodes
## and no motion. Colours are the series' own; every piece of text wears a text
## token, and only the line keys wear the series colour.

signal cursor_moved(day: int)

## Theme types the chart reads its fonts and frame from.
const TYPE_TITLE: StringName = &"LabelCaps"
const TYPE_CAPTION: StringName = &"LabelCaption"
const TYPE_DATA: StringName = &"ValueLabel"
const TYPE_FRAME: StringName = &"ChartFrame"
const TYPE_TOOLTIP: StringName = &"MapTooltip"
const FONT: StringName = &"font"
const FONT_SIZE: StringName = &"font_size"
const STYLE_PANEL: StringName = &"panel"
const STYLE_FOCUS: StringName = &"focus"
const KEY_EMPTY: String = "UI_ANALYSIS_EMPTY"
const KEY_X_DAYS: String = "UI_ANALYSIS_X_DAYS"
const KEY_CURSOR_DAY: String = "UI_ANALYSIS_CURSOR_DAY"
const PLACEHOLDER_DAY: String = "day"
## §6.2: the y gridlines as shares of the top.
const Y_TICKS: Array[float] = [0.25, 0.5, 0.75, 1.0]
## §6.2: `nice` picks the smallest of these × 10^k at or above a value.
const NICE_STEPS: Array[float] = [1.0, 2.0, 5.0]
## Auto `y_max` leaves this much headroom over the highest value.
const HEADROOM: float = 1.1
const LEGEND_KEY: Vector2 = Vector2(16.0, 2.0)
const LINE_KEY_W: float = 12.0
const TEXT_GAP: float = 4.0
const MOMENT_ALPHA: float = 0.6
const HAIRLINE: float = 1.0
const BASE_TEN: float = 10.0

@export var title_key: String = "":
	set(value):
		title_key = value
		accessibility_name = tr(value)
		queue_redraw()

var kind: Format.Kind = Format.Kind.PLAIN
## PLAIN only: how many places a value shows.
var decimals: int = 0
## PERCENT → `percent_fine`.
var fine: bool = false
## A single series gets the 10 % wash under its line.
var area: bool = true
## Auto `y_max` never goes below this (§5.3's "auto, ≥ n").
var min_span: float = 1.0
## §5.5: half height, no legend row.
var small: bool = false:
	set(value):
		small = value
		_apply_min_size()
## §5.10: the phone's shorter chart.
var compact: bool = false:
	set(value):
		compact = value
		_apply_min_size()

var _series: Array[ChartSeries] = []
var _day_max: int = UiTokens.MIN_SPAN_DAYS
## ≤ 0 = auto.
var _y_fixed: float = 0.0
var _bands: Array[Dictionary] = []
var _moments: Array[Dictionary] = []
var _references: Array[float] = []
var _cursor: int = -1


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_min_size()
	# A drawn colour is not a theme item: the Open palette has to be asked for.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		accessibility_name = tr(title_key)
		queue_redraw()


# ------------------------------------------------------------------------ API


func set_series(series: Array[ChartSeries]) -> void:
	_series = series
	if _cursor >= 0:
		_cursor = _snap(_cursor)
	_refresh_description()
	queue_redraw()


## The x domain is `[0, day_max]`; `y_max` ≤ 0 makes the y domain automatic.
func set_domain(day_max: int, y_max: float) -> void:
	_day_max = maxi(1, day_max)
	_y_fixed = y_max
	queue_redraw()


## `[{"from": int, "to": int, "key": String}]` — the phases.
func set_bands(bands: Array[Dictionary]) -> void:
	_bands = bands
	queue_redraw()


## `[{"day": int, "color": Color}]` — the discovery day.
func set_moments(moments: Array[Dictionary]) -> void:
	_moments = moments
	queue_redraw()


func set_reference_lines(values: Array[float]) -> void:
	_references = values
	queue_redraw()


## Snaps to the nearest sample; −1 clears. Emits nothing — the caller moved it.
func set_cursor(day: int) -> void:
	_cursor = -1 if day < 0 else _snap(day)
	_refresh_description()
	queue_redraw()


func cursor_day() -> int:
	return _cursor


func series() -> Array[ChartSeries]:
	return _series


## §6.6: `TABLE_ROWS` days evenly over `[0, day_max]`, each snapped to the
## nearest sample, plus the last sample — unique, ascending.
func table_days(day_max: int) -> PackedInt32Array:
	var all: PackedInt32Array = _sample_days()
	var out: PackedInt32Array = PackedInt32Array()
	if all.is_empty():
		return out
	for i: int in UiTokens.TABLE_ROWS:
		var wanted: int = roundi(float(day_max) * float(i) / float(UiTokens.TABLE_ROWS - 1))
		var snapped: int = _nearest(all, wanted)
		if not out.has(snapped):
			out.append(snapped)
	var last: int = all[all.size() - 1]
	if not out.has(last):
		out.append(last)
	out.sort()
	return out


## One value per series at `day`, NAN where a series has no sample there.
func values_at(day: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for one: ChartSeries in _series:
		out.append(one.value_at(day))
	return out


## A value in the chart's own form (`kind`, `decimals`, `fine`).
func format_value(value: float) -> String:
	if is_nan(value):
		return "—"
	if kind == Format.Kind.PERCENT and fine:
		return Format.percent_fine(value)
	if kind == Format.Kind.PLAIN and decimals > 0:
		return Format.decimal(value, decimals)
	return Format.number(value, kind)


# -------------------------------------------------------------------- scales


## §6.2: the smallest of {1, 2, 5} × 10^k at or above `value`.
static func nice(value: float) -> float:
	if value <= 0.0:
		return 1.0
	var power: float = pow(BASE_TEN, floorf(log(value) / log(BASE_TEN)))
	for step: float in NICE_STEPS:
		if step * power >= value - value * 1e-9:
			return step * power
	return BASE_TEN * power


## The top of the y domain: fixed, or `nice(max × 1.1)` floored at `min_span`.
func y_max() -> float:
	if _y_fixed > 0.0:
		return _y_fixed
	var highest: float = 0.0
	var stack: Dictionary[int, float] = {}
	for one: ChartSeries in _series:
		for i: int in one.values.size():
			var value: float = one.values[i]
			if is_nan(value):
				continue
			if one.stacked:
				stack[one.days[i]] = float(stack.get(one.days[i], 0.0)) + value
				value = stack[one.days[i]]
			highest = maxf(highest, value)
	return maxf(nice(highest * HEADROOM), min_span)


## The plot inside the frame, after the title, legend, axes and label gutter.
func plot_rect() -> Rect2:
	var top: float = UiTokens.CHART_TITLE_H + (UiTokens.CHART_LEGEND_H if _has_legend() else 0.0)
	return Rect2(UiTokens.CHART_AXIS_W, top,
		maxf(1.0, size.x - UiTokens.CHART_AXIS_W - UiTokens.CHART_LABEL_W),
		maxf(1.0, size.y - top - UiTokens.CHART_AXIS_H))


func day_to_x(day: float) -> float:
	var plot: Rect2 = plot_rect()
	return plot.position.x + day / float(_day_max) * plot.size.x


func value_to_y(value: float) -> float:
	var plot: Rect2 = plot_rect()
	return plot.end.y - value / y_max() * plot.size.y


## §6.2: the smallest of `CHART_X_TICKS` that leaves `CHART_TICK_MIN_PX`
## between two ticks at this plot width.
func x_tick_step(plot_width: float) -> int:
	for step: int in UiTokens.CHART_X_TICKS:
		if float(step) / float(_day_max) * plot_width >= UiTokens.CHART_TICK_MIN_PX:
			return step
	return UiTokens.CHART_X_TICKS[UiTokens.CHART_X_TICKS.size() - 1]


## §6.3: the end labels that survive — placed top to bottom, a label that
## would overlap one already placed is dropped, never nudged.
func end_labels() -> Array[Dictionary]:
	var wanted: Array[Dictionary] = []
	var cumulative: Dictionary[int, float] = {}
	for one: ChartSeries in _series:
		if one.values.is_empty():
			continue
		var last: int = one.values.size() - 1
		var value: float = one.values[last]
		var height: float = value
		if one.stacked:
			height = float(cumulative.get(one.days[last], 0.0)) + value
			cumulative[one.days[last]] = height
		wanted.append({"series": one, "value": value, "y": value_to_y(height)})
	wanted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["y"]) < float(b["y"]))
	var line_h: float = _font_height(TYPE_CAPTION)
	var placed: Array[Dictionary] = []
	for label: Dictionary in wanted:
		var top: float = float(label["y"]) - line_h * 0.5
		var clashes: bool = false
		for other: Dictionary in placed:
			if absf(float(other["top"]) - top) < line_h:
				clashes = true
				break
		if not clashes:
			label["top"] = top
			placed.append(label)
	return placed


# ---------------------------------------------------------------------- input


func _gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_cursor_to_x(motion.position.x)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		_cursor_to_x(drag.position.x)
		accept_event()
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	var days: PackedInt32Array = _sample_days()
	if days.is_empty():
		return
	var at: int = days.find(_cursor)
	match key.keycode:
		KEY_LEFT:
			at = maxi(0, at - 1) if at >= 0 else days.size() - 1
		KEY_RIGHT:
			at = mini(days.size() - 1, at + 1) if at >= 0 else 0
		KEY_HOME:
			at = 0
		KEY_END:
			at = days.size() - 1
		_:
			return
	_move_cursor(days[at])
	accept_event()


## The whole plot is the hit target, never the 2 px line (§6.5).
func _cursor_to_x(x: float) -> void:
	var plot: Rect2 = plot_rect()
	if x < plot.position.x - UiTokens.CHART_MARK_R or x > plot.end.x + UiTokens.CHART_MARK_R:
		return
	var day: float = (x - plot.position.x) / plot.size.x * float(_day_max)
	_move_cursor(_snap(roundi(day)))


func _move_cursor(day: int) -> void:
	if day == _cursor:
		return
	_cursor = day
	_refresh_description()
	queue_redraw()
	cursor_moved.emit(day)


# -------------------------------------------------------------------- drawing


func _draw() -> void:
	var frame: StyleBox = get_theme_stylebox(STYLE_PANEL, TYPE_FRAME)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	_draw_title()
	if _is_empty():
		_draw_empty()
	else:
		_draw_bands()
		_draw_grid()
		_draw_references()
		_draw_moments()
		_draw_series()
		_draw_legend()
		_draw_end_labels()
		_draw_cursor()
	if has_focus():
		draw_style_box(get_theme_stylebox(STYLE_FOCUS, TYPE_FRAME), Rect2(Vector2.ZERO, size))


func _draw_title() -> void:
	var font: Font = get_theme_font(FONT, TYPE_TITLE)
	var font_size: int = get_theme_font_size(FONT_SIZE, TYPE_TITLE)
	var baseline: float = UiTokens.CHART_TITLE_H * 0.5 + font.get_ascent(font_size) * 0.5
	draw_string(font, Vector2(UiTokens.CHART_AXIS_W, baseline), Format.caps(tr(title_key)),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - UiTokens.CHART_AXIS_W, font_size,
		UiTokens.color(&"TEXT_1"))


func _draw_empty() -> void:
	var plot: Rect2 = plot_rect()
	_caption(tr(KEY_EMPTY), Vector2(plot.position.x, plot.get_center().y), plot.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, UiTokens.color(&"TEXT_2"))


## Odd phase bands on `BG_3`, a hairline at every boundary, the phase name at
## the band's top-left when it fits.
func _draw_bands() -> void:
	var plot: Rect2 = plot_rect()
	for i: int in _bands.size():
		var band: Dictionary = _bands[i]
		var left: float = clampf(day_to_x(float(band["from"])), plot.position.x, plot.end.x)
		var right: float = clampf(day_to_x(float(band["to"])), plot.position.x, plot.end.x)
		if i % 2 == 1:
			draw_rect(Rect2(left, plot.position.y, right - left, plot.size.y),
				UiTokens.color(&"BG_3"))
		if i > 0:
			draw_line(Vector2(left, plot.position.y), Vector2(left, plot.end.y),
				UiTokens.color(&"LINE_1"), HAIRLINE)
		var name: String = Format.caps(tr(str(band.get("key", ""))))
		var font: Font = get_theme_font(FONT, TYPE_TITLE)
		var font_size: int = get_theme_font_size(FONT_SIZE, TYPE_TITLE)
		var width: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
		if right - left > width + TEXT_GAP * 2.0:
			draw_string(font, Vector2(left + TEXT_GAP, plot.position.y + font.get_ascent(
				font_size) + TEXT_GAP), name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				UiTokens.color(&"TEXT_2"))


func _draw_grid() -> void:
	var plot: Rect2 = plot_rect()
	var top: float = y_max()
	for share: float in Y_TICKS:
		var y: float = value_to_y(top * share)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), UiTokens.color(&"LINE_0"),
			HAIRLINE)
		_caption(format_value(top * share), Vector2(0.0, y), UiTokens.CHART_AXIS_W - TEXT_GAP,
			HORIZONTAL_ALIGNMENT_RIGHT, UiTokens.color(&"TEXT_2"))
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y),
		UiTokens.color(&"LINE_1"), HAIRLINE)
	var step: int = x_tick_step(plot.size.x)
	var label_y: float = plot.end.y + UiTokens.CHART_AXIS_H * 0.5
	# The axis caption ends at the frame's right edge and the tick labels give
	# way to it: *Tage seit dem Ursprung* is wider than the label gutter.
	var caption: String = tr(KEY_X_DAYS)
	var caption_left: float = size.x - TEXT_GAP - _caption_width(caption)
	var day: int = 0
	while day <= _day_max:
		var x: float = day_to_x(float(day))
		var label: String = Format.number(float(day), Format.Kind.DAYS)
		if x + _caption_width(label) * 0.5 < caption_left - TEXT_GAP:
			_caption(label, Vector2(x - UiTokens.CHART_AXIS_W, label_y),
				UiTokens.CHART_AXIS_W * 2.0, HORIZONTAL_ALIGNMENT_CENTER, UiTokens.color(&"TEXT_2"))
		day += step
	_caption(caption, Vector2(caption_left, label_y), size.x - caption_left,
		HORIZONTAL_ALIGNMENT_LEFT, UiTokens.color(&"TEXT_2"))


func _draw_references() -> void:
	var plot: Rect2 = plot_rect()
	for value: float in _references:
		var y: float = value_to_y(value)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), UiTokens.color(&"LINE_1"),
			HAIRLINE)


func _draw_moments() -> void:
	var plot: Rect2 = plot_rect()
	for moment: Dictionary in _moments:
		var x: float = day_to_x(float(moment["day"]))
		var colour: Color = moment["color"]
		colour.a = MOMENT_ALPHA
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), colour, HAIRLINE)


## Lines and their washes; stacked series as cumulative areas with a 2 px
## surface line on every boundary.
func _draw_series() -> void:
	var plot: Rect2 = plot_rect()
	var base: Dictionary[int, float] = {}
	var single: bool = _series.size() == 1
	for one: ChartSeries in _series:
		var points: PackedVector2Array = PackedVector2Array()
		var floor_points: PackedVector2Array = PackedVector2Array()
		for i: int in one.days.size():
			var value: float = one.values[i]
			if is_nan(value):
				continue
			var below: float = float(base.get(one.days[i], 0.0)) if one.stacked else 0.0
			var x: float = day_to_x(float(one.days[i]))
			points.append(Vector2(x, value_to_y(below + value)))
			floor_points.append(Vector2(x, value_to_y(below)))
			if one.stacked:
				base[one.days[i]] = below + value
		if points.size() < 2:
			continue
		if one.stacked:
			var polygon: PackedVector2Array = points.duplicate()
			floor_points.reverse()
			polygon.append_array(floor_points)
			var fill: Color = one.color
			fill.a = UiTokens.CHART_STACK_ALPHA
			draw_colored_polygon(polygon, fill)
			draw_polyline(points, UiTokens.color(&"BG_2"), UiTokens.CHART_RING_W, true)
			continue
		if single and area:
			var wash: PackedVector2Array = points.duplicate()
			wash.append(Vector2(points[points.size() - 1].x, plot.end.y))
			wash.append(Vector2(points[0].x, plot.end.y))
			var tint: Color = one.color
			tint.a = UiTokens.CHART_AREA_ALPHA
			draw_colored_polygon(wash, tint)
		draw_polyline(points, one.color, UiTokens.CHART_LINE_W, true)


func _draw_legend() -> void:
	if not _has_legend():
		return
	var x: float = UiTokens.CHART_AXIS_W
	var y: float = UiTokens.CHART_TITLE_H + UiTokens.CHART_LEGEND_H * 0.5
	for one: ChartSeries in _series:
		var name: String = tr(one.key)
		var width: float = _caption_width(name)
		if x + LEGEND_KEY.x + TEXT_GAP + width > size.x - TEXT_GAP:
			break
		draw_rect(Rect2(x, y - LEGEND_KEY.y * 0.5, LEGEND_KEY.x, LEGEND_KEY.y), one.color)
		x += LEGEND_KEY.x + TEXT_GAP
		_caption(name, Vector2(x, y), width, HORIZONTAL_ALIGNMENT_LEFT, UiTokens.color(&"TEXT_1"))
		x += width + TEXT_GAP * 3.0


func _draw_end_labels() -> void:
	var plot: Rect2 = plot_rect()
	for label: Dictionary in end_labels():
		var one: ChartSeries = label["series"]
		var y: float = float(label["y"])
		var x: float = plot.end.x + TEXT_GAP
		draw_line(Vector2(x, y), Vector2(x + LINE_KEY_W, y), one.color, UiTokens.CHART_LINE_W)
		_caption(format_value(float(label["value"])), Vector2(x + LINE_KEY_W + TEXT_GAP, y),
			UiTokens.CHART_LABEL_W - LINE_KEY_W - TEXT_GAP * 2.0, HORIZONTAL_ALIGNMENT_LEFT,
			UiTokens.color(&"TEXT_1"))


## A hairline at the cursor, a ringed marker on every series, and the tooltip
## beside it, flipped when it would leave the chart.
func _draw_cursor() -> void:
	if _cursor < 0:
		return
	var plot: Rect2 = plot_rect()
	var x: float = day_to_x(float(_cursor))
	draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), UiTokens.color(&"LINE_2"),
		HAIRLINE)
	var base: float = 0.0
	var rows: Array[Array] = []
	for one: ChartSeries in _series:
		var value: float = one.value_at(_cursor)
		if is_nan(value):
			continue
		var height: float = value
		if one.stacked:
			base += value
			height = base
		var point: Vector2 = Vector2(x, value_to_y(height))
		draw_circle(point, UiTokens.CHART_MARK_R + UiTokens.CHART_RING_W, UiTokens.color(&"BG_2"))
		draw_circle(point, UiTokens.CHART_MARK_R, one.color)
		rows.append([format_value(value), tr(one.key), one.color])
	_draw_tooltip(x, rows)


func _draw_tooltip(x: float, rows: Array[Array]) -> void:
	var box: StyleBox = get_theme_stylebox(STYLE_PANEL, TYPE_TOOLTIP)
	var data_font: Font = get_theme_font(FONT, TYPE_DATA)
	var data_size: int = get_theme_font_size(FONT_SIZE, TYPE_DATA)
	var line_h: float = maxf(_font_height(TYPE_DATA), _font_height(TYPE_CAPTION))
	var head: String = tr(KEY_CURSOR_DAY).format({PLACEHOLDER_DAY:
		Format.number(float(_cursor), Format.Kind.DAYS)})
	var width: float = _caption_width(head)
	for row: Array in rows:
		width = maxf(width, LINE_KEY_W + TEXT_GAP + data_font.get_string_size(str(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, data_size).x + TEXT_GAP + _caption_width(str(row[1])))
	var pad: Vector2 = Vector2(box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT),
		box.get_margin(SIDE_TOP) + box.get_margin(SIDE_BOTTOM))
	var extent: Vector2 = Vector2(width, line_h * float(rows.size() + 1)) + pad
	var plot: Rect2 = plot_rect()
	var left: float = x + TEXT_GAP * 2.0
	if left + extent.x > size.x:
		left = x - TEXT_GAP * 2.0 - extent.x
	var top: float = clampf(plot.position.y, 0.0, maxf(0.0, size.y - extent.y))
	var rect: Rect2 = Rect2(Vector2(maxf(0.0, left), top), extent)
	draw_style_box(box, rect)
	var origin: Vector2 = rect.position + Vector2(box.get_margin(SIDE_LEFT),
		box.get_margin(SIDE_TOP))
	_caption(head, origin + Vector2(0.0, line_h * 0.5), width, HORIZONTAL_ALIGNMENT_LEFT,
		UiTokens.color(&"TEXT_1"))
	for i: int in rows.size():
		var y: float = origin.y + line_h * (float(i) + 1.5)
		var colour: Color = rows[i][2]
		draw_line(Vector2(origin.x, y), Vector2(origin.x + LINE_KEY_W, y), colour,
			UiTokens.CHART_LINE_W)
		var value_x: float = origin.x + LINE_KEY_W + TEXT_GAP
		draw_string(data_font, Vector2(value_x, y + data_font.get_ascent(data_size) * 0.4),
			str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, data_size, UiTokens.color(&"TEXT_0"))
		var name_x: float = value_x + data_font.get_string_size(str(rows[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, data_size).x + TEXT_GAP
		_caption(str(rows[i][1]), Vector2(name_x, y), width, HORIZONTAL_ALIGNMENT_LEFT,
			UiTokens.color(&"TEXT_1"))


# -------------------------------------------------------------------- helpers


## One caption, vertically centred on `centre.y`, inside `width` from
## `centre.x` (or ending there with `right_of`).
func _caption(text: String, centre: Vector2, width: float, align: HorizontalAlignment,
		colour: Color, right_of: bool = false) -> void:
	var font: Font = get_theme_font(FONT, TYPE_CAPTION)
	var font_size: int = get_theme_font_size(FONT_SIZE, TYPE_CAPTION)
	var x: float = centre.x
	if right_of:
		x = centre.x + UiTokens.CHART_LABEL_W - width - TEXT_GAP
	draw_string(font, Vector2(x, centre.y + font.get_ascent(font_size) * 0.4), text, align,
		width, font_size, colour)


func _caption_width(text: String) -> float:
	var font: Font = get_theme_font(FONT, TYPE_CAPTION)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		get_theme_font_size(FONT_SIZE, TYPE_CAPTION)).x


func _font_height(type: StringName) -> float:
	return get_theme_font(FONT, type).get_height(get_theme_font_size(FONT_SIZE, type))


func _has_legend() -> bool:
	return _series.size() >= 2 and not small


## §6.4: fewer than two points in every series.
func _is_empty() -> bool:
	for one: ChartSeries in _series:
		var points: int = 0
		for value: float in one.values:
			if not is_nan(value):
				points += 1
		if points >= 2:
			return false
	return true


## Every day any series has a sample on, ascending.
func _sample_days() -> PackedInt32Array:
	var seen: Dictionary[int, bool] = {}
	for one: ChartSeries in _series:
		for day: int in one.days:
			seen[day] = true
	var out: PackedInt32Array = PackedInt32Array(seen.keys())
	out.sort()
	return out


func _snap(day: int) -> int:
	var days: PackedInt32Array = _sample_days()
	return -1 if days.is_empty() else _nearest(days, day)


static func _nearest(days: PackedInt32Array, day: int) -> int:
	var at: int = days.bsearch(day)
	if at >= days.size():
		return days[days.size() - 1]
	if at == 0 or days[at] == day:
		return days[at]
	return days[at] if days[at] - day < day - days[at - 1] else days[at - 1]


func _apply_min_size() -> void:
	var height: int = UiTokens.CHART_MIN_HEIGHT
	if small:
		height = UiTokens.CHART_MIN_HEIGHT_SMALL
	elif compact:
		height = UiTokens.CHART_MIN_HEIGHT_COMPACT
	custom_minimum_size.y = float(height)


## §6.5: the cursor readout as a sentence, for a screen reader.
func _refresh_description() -> void:
	if _cursor < 0:
		accessibility_description = ""
		return
	var parts: PackedStringArray = PackedStringArray()
	for one: ChartSeries in _series:
		parts.append("%s %s" % [tr(one.key), format_value(one.value_at(_cursor))])
	accessibility_description = "%s: %s" % [tr(KEY_CURSOR_DAY).format({PLACEHOLDER_DAY:
		Format.number(float(_cursor), Format.Kind.DAYS)}), ", ".join(parts)]


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()
