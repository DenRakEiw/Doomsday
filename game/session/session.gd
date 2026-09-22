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

@onready var _safe_area: MarginContainer = %SafeArea


func _ready() -> void:
	# §5.1: the session root carries the theme. `project.godot` names the same
	# theme so the editor knows the type variations, but only an assignment here
	# can be swapped at runtime — which is what D3.3's phase palette needs.
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	get_window().size_changed.connect(_on_window_size_changed)
	_apply_logical_scale()
	_apply_safe_area()


func _on_window_size_changed() -> void:
	_apply_logical_scale()
	_apply_safe_area()


## Mobile lays out in dp, so that `HIT_MIN` is 48 dp and the compact breakpoint
## is one rule everywhere. Desktop keeps the 1920×1080 base of `project.godot`.
func _apply_logical_scale() -> void:
	if not OS.has_feature("mobile"):
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
