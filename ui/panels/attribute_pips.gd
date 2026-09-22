class_name AttributePips
extends Control
## A region's tier in one attribute as four squares (spec ui-foundation.md §5.6).
##
## Four filled squares are read at a glance and need no number, no bar and no
## colour of their own — the profile is a shape, not a measurement.
##
## §5.6 asks for a `_draw` in the region panel itself. A cell of a
## `GridContainer` is a node, so the drawing has to be one: this is that node,
## and it is the whole of it.

## A screen reader hears the tier; the squares are for the eye (§5.6).
const KEY_TIER: String = "UI_ATTR_TIER"
const PLACEHOLDER_TIER: String = "tier"

## How many of the four squares are filled, 0 … `RegionDef.TIER_MAX`.
var tier: int = 0:
	set(value):
		var wanted: int = clampi(value, RegionDef.TIER_MIN, RegionDef.TIER_MAX)
		if wanted == tier:
			return
		tier = wanted
		_refresh_strings()
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _wanted_size()
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_strings()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	var side: float = float(UiTokens.PIP_SIZE)
	var top: float = floorf((size.y - side) * 0.5)
	for i: int in RegionDef.TIER_MAX:
		var box: Rect2 = Rect2(Vector2(float(i) * float(UiTokens.PIP_SIZE + UiTokens.PIP_GAP),
			top), Vector2(side, side))
		if i < tier:
			draw_rect(box, UiTokens.TEXT_0)
		else:
			# An empty pip is an outline: the row keeps its shape at every tier.
			# `LINE_2` and not the default border — on `BG_2` `LINE_1` vanished
			# and the row read as fewer pips than it has (G2).
			draw_rect(box, UiTokens.LINE_2, false, float(UiTokens.BORDER))


func _wanted_size() -> Vector2:
	var count: int = RegionDef.TIER_MAX
	return Vector2(float(count * UiTokens.PIP_SIZE + (count - 1) * UiTokens.PIP_GAP),
		float(UiTokens.PIP_SIZE))


func _refresh_strings() -> void:
	accessibility_name = tr(KEY_TIER).format({PLACEHOLDER_TIER: tier})
