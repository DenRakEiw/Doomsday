class_name LogicalScale
extends RefCounted
## The logical pixel of spec ui-foundation.md §6.1, for every screen.
##
## Mobile lays out in dp, so that `HIT_MIN` is 48 dp and the compact breakpoint
## is one rule everywhere. Desktop keeps the 1920×1080 base of `project.godot` —
## except in a window narrower than the breakpoint, where it would otherwise
## show the wide layout shrunk and §5.7's compact layout could never be seen at
## all. The session did this alone until S5.7; the title and the setup need it
## too, so `main.gd` and the session both ask here.
##
## Never instantiated; a namespace of static functions.

## One logical pixel is one dp: a dp is a 160th of an inch.
const DP_PER_INCH: float = 160.0
const SETTING_BASE_WIDTH: String = "display/window/size/viewport_width"
const SETTING_BASE_HEIGHT: String = "display/window/size/viewport_height"
## What `DisplayServer.get_name()` answers when there is no window at all.
const HEADLESS_DRIVER: String = "headless"
const FEATURE_MOBILE: String = "mobile"


## Sets the window's content scale for its current size.
static func apply(window: Window) -> void:
	if window == null:
		return
	if not OS.has_feature(FEATURE_MOBILE):
		_apply_desktop(window)
		return
	var dpi: float = float(DisplayServer.screen_get_dpi(window.current_screen))
	if dpi <= 0.0:
		return
	var wanted: Vector2i = Vector2i(
		roundi(float(window.size.x) * DP_PER_INCH / dpi),
		roundi(float(window.size.y) * DP_PER_INCH / dpi))
	# Assigning the same size again would re-enter through `size_changed`.
	if wanted != window.content_scale_size:
		window.content_scale_size = wanted


## One logical pixel per window pixel below the breakpoint, the project's base
## above it.
##
## A headless run is left alone: it has no window to lay out for, and the size
## the dummy driver reports would silently re-scale the viewport every test that
## puts a screen in the tree.
static func _apply_desktop(window: Window) -> void:
	if DisplayServer.get_name() == HEADLESS_DRIVER:
		return
	var wanted: Vector2i = project_base()
	if window.size.x < UiTokens.COMPACT_WIDTH:
		wanted = window.size
	if wanted != window.content_scale_size:
		window.content_scale_size = wanted


static func project_base() -> Vector2i:
	return Vector2i(
		int(ProjectSettings.get_setting(SETTING_BASE_WIDTH)),
		int(ProjectSettings.get_setting(SETTING_BASE_HEIGHT)))
