class_name StatBarFill
extends Control
## The trough and the fill of a `StatBar` (spec ui-foundation.md §4.4).
##
## A separate node because a theme type variation reaches the node it is set on,
## not that node's children: the fill has to *be* the `StatBar` type to read
## `fill`, `trough` and the bar's geometry from it. `StatBar` hands it its own
## variation, so `StatBarPenetration` colours the bar it belongs to.
##
## Nothing here is animated on its own — `StatBar` tweens `displayed_value`.

const COLOR_FILL: StringName = &"fill"
const COLOR_TROUGH: StringName = &"trough"
const COLOR_TROUGH_BORDER: StringName = &"trough_border"
const CONST_BAR_HEIGHT: StringName = &"bar_height"
const CONST_BAR_RADIUS: StringName = &"bar_radius"
const CONST_BAR_BORDER: StringName = &"bar_border"

## 0 … 1, the share the fill covers. Tweened by `StatBar`, never set directly by
## a screen.
var displayed_value: float = 0.0:
	set(value):
		displayed_value = clampf(value, 0.0, 1.0)
		queue_redraw()

var _trough: StyleBoxFlat = null
var _fill: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild_styles()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_rebuild_styles()
		queue_redraw()


func _draw() -> void:
	if _trough == null:
		_rebuild_styles()
	var height: float = float(get_theme_constant(CONST_BAR_HEIGHT))
	var top: float = floorf((size.y - height) * 0.5)
	var trough_rect: Rect2 = Rect2(Vector2(0.0, top), Vector2(size.x, height))
	draw_style_box(_trough, trough_rect)
	if displayed_value <= 0.0:
		return
	# The fill keeps the trough's radius, so a nearly empty bar still reads as a
	# bar rather than as a sliver of a rectangle.
	var width: float = maxf(trough_rect.size.x * displayed_value, float(UiTokens.RADIUS_S) * 2.0)
	draw_style_box(_fill, Rect2(trough_rect.position, Vector2(width, height)))


## The two boxes are rebuilt from the theme rather than created per frame, and
## every value in them comes from the theme.
func _rebuild_styles() -> void:
	var radius: int = get_theme_constant(CONST_BAR_RADIUS)
	var border: int = get_theme_constant(CONST_BAR_BORDER)
	# The row it sits in has to leave the bar its height, whatever else is in it.
	custom_minimum_size.y = float(get_theme_constant(CONST_BAR_HEIGHT))
	_trough = StyleBoxFlat.new()
	_trough.bg_color = get_theme_color(COLOR_TROUGH)
	_trough.border_color = get_theme_color(COLOR_TROUGH_BORDER)
	_trough.set_border_width_all(border)
	_trough.set_corner_radius_all(radius)
	_fill = StyleBoxFlat.new()
	_fill.bg_color = get_theme_color(COLOR_FILL)
	_fill.set_corner_radius_all(radius)
