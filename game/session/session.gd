extends Control
## The session root: the layer stack of spec ui-foundation.md §5.1, the logical
## pixel base of §6.1 and the safe-area margins of §6.3.
##
## S2.2–S2.6 fill the layers — map, HUD, panels; this step builds the frame they
## hang in and makes sure it is measured in the same unit on every device.
##
## Scene-specific, so no `class_name`.

## One logical pixel is one dp: a dp is a 160th of an inch (§6.1).
const DP_PER_INCH: float = 160.0
## The margins are runtime values — the display's, not the design's — and a
## `MarginContainer` takes them as theme constants only. This is the one place
## in the project that overrides one (CLAUDE.md "no per-node overrides").
const MARGIN_CONSTANTS: Array[String] = ["margin_left", "margin_top", "margin_right",
	"margin_bottom"]
## The base the project lays out at, which is also what a desktop window returns
## to when it is wide enough again.
const SETTING_BASE_WIDTH: String = "display/window/size/viewport_width"
const SETTING_BASE_HEIGHT: String = "display/window/size/viewport_height"
## What `DisplayServer.get_name()` answers when there is no window at all.
const HEADLESS_DRIVER: String = "headless"

@onready var _safe_area: MarginContainer = %SafeArea
@onready var _hud: Control = %Hud
@onready var _region_panel: SlidePanel = %RegionPanel


func _ready() -> void:
	# §5.1: the session root carries the theme. `project.godot` names the same
	# theme so the editor knows the type variations, but only an assignment here
	# can be swapped at runtime — which is what D3.3's phase palette needs.
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	get_window().size_changed.connect(_on_window_size_changed)
	# The HUD owns the breakpoint (§5.7); the panel beside it only has to be told
	# which edge it comes in from and how much of the screen it must leave alone.
	_hud.connect(&"layout_changed", _on_hud_layout_changed)
	_apply_logical_scale()
	_apply_safe_area()


func _on_window_size_changed() -> void:
	_apply_logical_scale()
	_apply_safe_area()


## §5.7: a side panel in the wide layout, a bottom sheet in the compact one. The
## insets are the HUD's measured strips, not a repeat of their design heights.
func _on_hud_layout_changed(compact: bool) -> void:
	_region_panel.edge = SlidePanel.Edge.BOTTOM if compact else SlidePanel.Edge.LEFT
	_region_panel.top_inset = float(_hud.call(&"top_inset"))
	_region_panel.bottom_inset = float(_hud.call(&"bottom_inset"))


## Mobile lays out in dp, so that `HIT_MIN` is 48 dp and the compact breakpoint
## is one rule everywhere (§6.1). Desktop keeps the 1920×1080 base of
## `project.godot` — except in a window narrower than the breakpoint, where it
## would otherwise show the wide layout shrunk and §5.7's compact layout could
## never be seen at all. `ui/dev/gallery.gd` does the same for the same reason.
func _apply_logical_scale() -> void:
	if not OS.has_feature("mobile"):
		_apply_desktop_scale()
		return
	var window: Window = get_window()
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
## puts this scene in the tree.
func _apply_desktop_scale() -> void:
	if DisplayServer.get_name() == HEADLESS_DRIVER:
		return
	var window: Window = get_window()
	var wanted: Vector2i = _project_base()
	if window.size.x < UiTokens.COMPACT_WIDTH:
		wanted = window.size
	if wanted != window.content_scale_size:
		window.content_scale_size = wanted


func _project_base() -> Vector2i:
	return Vector2i(
		int(ProjectSettings.get_setting(SETTING_BASE_WIDTH)),
		int(ProjectSettings.get_setting(SETTING_BASE_HEIGHT)))


## `GUTTER` is added by each block inside, never here.
func _apply_safe_area() -> void:
	var margins: Vector4i = _safe_area_margins()
	var values: Array[int] = [margins.x, margins.y, margins.z, margins.w]
	for i: int in MARGIN_CONSTANTS.size():
		_safe_area.add_theme_constant_override(MARGIN_CONSTANTS[i], values[i])


## Left, top, right, bottom in logical pixels. Desktop has none: UI.md warns that
## the Windows query counts the taskbar, and a window is its own safe area.
func _safe_area_margins() -> Vector4i:
	if not OS.has_feature("mobile"):
		return Vector4i.ZERO
	var window: Window = get_window()
	var window_px: Vector2i = window.size
	if window_px.x <= 0 or window_px.y <= 0:
		return Vector4i.ZERO
	var logical: Vector2i = window.content_scale_size
	var per_px: Vector2 = Vector2(
		float(logical.x) / float(window_px.x), float(logical.y) / float(window_px.y))
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	return Vector4i(
		roundi(float(safe.position.x) * per_px.x),
		roundi(float(safe.position.y) * per_px.y),
		roundi(float(window_px.x - safe.end.x) * per_px.x),
		roundi(float(window_px.y - safe.end.y) * per_px.y))
