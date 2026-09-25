extends CanvasLayer
## The full-screen pass (spec polish-visuals.md §3–§6): one `ColorRect` with one
## shader above everything — boot, title, setup, session, every modal and
## tooltip — and the triggers that drive it: heat, impulses, the alert wash,
## the screen dissolve.
##
## Every full-screen luminance change goes through here and asks the
## `FlashLimiter` (§6). The rules are `ScreenFxRules`; this node only listens,
## tweens and sets uniforms.
##
## An autoload, registered last (it listens to `ScreenRouter`), so no
## `class_name`.

const SHADER: Shader = preload("res://ui/fx/screen_fx.gdshader")

## §3.6: the keys of `UiTokens.FX_HEAT_SCREEN` for the screens outside a run.
const HEAT_BOOT: StringName = &"boot"
const HEAT_TITLE: StringName = &"title"
const HEAT_SETUP: StringName = &"setup"

const U_PX_SCALE: StringName = &"px_scale"
const U_CA_PX: StringName = &"ca_px"
const U_BLOOM_STRENGTH: StringName = &"bloom_strength"
const U_BLOOM_TAPS: StringName = &"bloom_taps"
const U_BLOOM_RADII: StringName = &"bloom_radii"
const U_BLOOM_KEY: StringName = &"bloom_key"
const U_WASH: StringName = &"wash"
const U_VIGNETTE: StringName = &"vignette"
const U_VIGNETTE_START: StringName = &"vignette_start"
const U_SCAN_DEPTH: StringName = &"scan_depth"
const U_SCAN_PERIOD: StringName = &"scan_period"
const U_GRAIN_AMP: StringName = &"grain_amp"
const U_GRAIN_FPS: StringName = &"grain_fps"
const U_DITHER_LEVELS: StringName = &"dither_levels"
const U_DISSOLVE: StringName = &"dissolve"
const U_DISSOLVE_CELL: StringName = &"dissolve_cell"
const U_GROUND: StringName = &"ground"
## The smallest scanline period that is still a line and not a fill.
const SCAN_PERIOD_MIN: int = 2
## Two heats closer than this are the same; no tween starts for less.
const HEAT_EPSILON: float = 0.001

var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _limiter: FlashLimiter = FlashLimiter.new()
var _params: ScreenFxParams = ScreenFxParams.new()
var _px_scale: float = 1.0
## The setting, 0…1 (`Settings.screen_effects`).
var _intensity: float = 1.0
var _heat: float = 0.0
var _heat_target: float = 0.0
var _heat_tween: Tween = null
## §4.1: what is left of the last impulse, and when it was accepted (-1: never).
var _impulse: float = 0.0
var _impulse_at: int = -1
var _wash_alpha: float = 0.0
var _wash_tween: Tween = null
var _dissolve: float = 0.0
var _dissolve_tween: Tween = null


func _ready() -> void:
	layer = UiTokens.FX_LAYER
	# The pass keeps drawing (grain, a dissolve) while anything holds the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_intensity = _setting_intensity()
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.reduced_motion_changed.connect(_on_reduced_motion_changed)
	EventBus.screen_effects_changed.connect(_on_screen_effects_changed)
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	ScreenRouter.screen_changed.connect(_on_screen_changed)
	get_tree().root.size_changed.connect(_on_size_changed)
	_on_size_changed()
	_heat = _heat_for_screen(ScreenRouter.current)
	_heat_target = _heat
	_send_constants()
	_apply()


func _process(delta: float) -> void:
	if _impulse <= 0.0:
		return
	_impulse *= exp(-delta * UiTokens.MS_PER_SECOND / float(UiTokens.FX_CA_DECAY))
	if _impulse < UiTokens.FX_CA_FLOOR:
		_impulse = 0.0
	_material.set_shader_parameter(U_CA_PX, _ca_px())


# ------------------------------------------------------------------- public


## §4.1: tears the frame for a moment. Within the cooldown only a stronger
## impulse is taken, and it does not restart the cooldown.
func impulse(strength: float) -> void:
	if strength <= 0.0:
		return
	var now: int = Time.get_ticks_msec()
	if _impulse_at >= 0 and now - _impulse_at < UiTokens.FX_IMPULSE_COOLDOWN:
		_impulse = maxf(_impulse, strength)
	else:
		_impulse = strength
		_impulse_at = now
	_material.set_shader_parameter(U_CA_PX, _ca_px())


## §4.2: the red wash of the discovery moment. Not decoration, so it ignores the
## setting and shows the pass while it lasts; reduced motion skips it, and the
## flash limiter may refuse it.
func flash_alert() -> void:
	if UiTokens.reduced_motion():
		return
	if not _limiter.allow(Time.get_ticks_msec()):
		return
	if _wash_tween != null and _wash_tween.is_valid():
		_wash_tween.kill()
	_set_wash(UiTokens.ALERT_FLASH_ALPHA)
	_wash_tween = create_tween()
	_wash_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_wash_tween.tween_method(_set_wash, _wash_alpha, 0.0,
		UiTokens.duration(UiTokens.MOTION_ALERT))


## §4.3: the new screen appears out of the ground through the dither cells.
## Reduced motion is a cut. Like the wash it ignores the setting.
func dissolve_in() -> void:
	if _dissolve_tween != null and _dissolve_tween.is_valid():
		_dissolve_tween.kill()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_DISSOLVE)
	if seconds <= 0.0:
		_set_dissolve(0.0)
		return
	_set_dissolve(1.0)
	_dissolve_tween = create_tween()
	_dissolve_tween.tween_method(_set_dissolve, 1.0, 0.0, seconds)


## Whether the pass is drawn this frame.
func is_shown() -> bool:
	return _rect.visible


func params() -> ScreenFxParams:
	return _params


func heat() -> float:
	return _heat


func impulse_strength() -> float:
	return _impulse


func dissolve_value() -> float:
	return _dissolve


func wash_alpha() -> float:
	return _wash_alpha


func pass_rect() -> ColorRect:
	return _rect


# ------------------------------------------------------------------ private


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Pass"
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


## The uniforms that only change with the window or the palette.
func _send_constants() -> void:
	_material.set_shader_parameter(U_BLOOM_RADII, UiTokens.FX_BLOOM_RADII)
	_material.set_shader_parameter(U_BLOOM_KEY, UiTokens.FX_BLOOM_KEY)
	_material.set_shader_parameter(U_VIGNETTE_START, UiTokens.FX_VIGNETTE_START)
	_material.set_shader_parameter(U_GRAIN_FPS, UiTokens.FX_GRAIN_FPS)
	_material.set_shader_parameter(U_GROUND, UiTokens.color(&"BG_0"))
	_set_wash(_wash_alpha)


## Re-derives the parameters and sends them.
func _apply() -> void:
	_params = ScreenFxRules.params(_intensity, _heat, UiTokens.reduced_motion())
	_material.set_shader_parameter(U_BLOOM_STRENGTH, _params.bloom_strength)
	_material.set_shader_parameter(U_BLOOM_TAPS, _params.bloom_taps)
	_material.set_shader_parameter(U_VIGNETTE, _params.vignette)
	_material.set_shader_parameter(U_SCAN_DEPTH, _params.scan_depth)
	_material.set_shader_parameter(U_GRAIN_AMP, _params.grain_amp)
	_material.set_shader_parameter(U_DITHER_LEVELS, _params.dither_levels)
	_material.set_shader_parameter(U_CA_PX, _ca_px())
	_update_visibility()


## §3.1: a hidden pass costs nothing, not even the screen copy.
func _update_visibility() -> void:
	_rect.visible = _params.enabled or _wash_alpha > 0.0 or _dissolve > 0.0


func _ca_px() -> float:
	return UiTokens.FX_CA_PX * _impulse * _params.ca_scale


func _set_wash(alpha: float) -> void:
	_wash_alpha = alpha
	_material.set_shader_parameter(U_WASH, Color(UiTokens.color(&"ALERT"), alpha))
	_update_visibility()


func _set_dissolve(value: float) -> void:
	_dissolve = value
	_material.set_shader_parameter(U_DISSOLVE, value)
	_update_visibility()


func _set_heat(value: float) -> void:
	_heat = value
	_apply()


## Moves the heat to `target`, over `MOTION_HEAT` unless `instant` or motion is
## reduced.
func _heat_to(target: float, instant: bool) -> void:
	var seconds: float = 0.0 if instant else UiTokens.duration(UiTokens.MOTION_HEAT)
	var tweening: bool = _heat_tween != null and _heat_tween.is_valid()
	if seconds > 0.0 and absf(target - _heat_target) < HEAT_EPSILON:
		return
	if seconds <= 0.0 and not tweening and absf(target - _heat) < HEAT_EPSILON:
		return
	_heat_target = target
	if _heat_tween != null and _heat_tween.is_valid():
		_heat_tween.kill()
	if seconds <= 0.0:
		_set_heat(target)
		return
	_heat_tween = create_tween()
	_heat_tween.tween_method(_set_heat, _heat, target, seconds)


func _run_heat() -> float:
	if Game.sim == null or Game.db == null:
		return UiTokens.FX_HEAT_PHASE[World.Phase.BOXED]
	var world: World = Game.sim.world
	return ScreenFxRules.heat(world.phase, ScreenFxRules.endgame(world, Game.db))


func _heat_for_screen(screen: int) -> float:
	var key: StringName = &""
	if screen == ScreenRouter.Screen.BOOT:
		key = HEAT_BOOT
	elif screen == ScreenRouter.Screen.TITLE:
		key = HEAT_TITLE
	elif screen == ScreenRouter.Screen.SETUP:
		key = HEAT_SETUP
	else:
		return _run_heat()
	return UiTokens.FX_HEAT_SCREEN.get(key, 0.0)


func _setting_intensity() -> float:
	return clampf(Settings.screen_effects, 0.0, 1.0)


# ---------------------------------------------------------------- handlers


## A new run starts clinical, a loaded one at its phase's heat — both at once.
func _on_run_started(_seed_value: int) -> void:
	_heat_to(_run_heat(), true)


func _on_tick_advanced(_day: int) -> void:
	_heat_to(_run_heat(), false)


func _on_sim_event(event: SimEvent) -> void:
	impulse(ScreenFxRules.impulse_for(event, Game.db))


func _on_screen_changed(screen: int) -> void:
	_heat_to(_heat_for_screen(screen), true)


func _on_reduced_motion_changed(_enabled: bool) -> void:
	_apply()


func _on_screen_effects_changed(_intensity_value: float) -> void:
	_intensity = _setting_intensity()
	_apply()


func _on_theme_variant_changed(_variant: StringName) -> void:
	_material.set_shader_parameter(U_GROUND, UiTokens.color(&"BG_0"))
	_set_wash(_wash_alpha)


func _on_size_changed() -> void:
	# Physical pixels: the shader's `FRAGCOORD` counts them, not logical ones.
	var pixels: Vector2 = Vector2(get_tree().root.size)
	_px_scale = minf(pixels.x, pixels.y) / UiTokens.FX_REFERENCE_HEIGHT
	_material.set_shader_parameter(U_PX_SCALE, _px_scale)
	_material.set_shader_parameter(U_SCAN_PERIOD,
		maxi(SCAN_PERIOD_MIN, roundi(float(UiTokens.FX_SCANLINE_PERIOD) * _px_scale)))
	_material.set_shader_parameter(U_DISSOLVE_CELL, UiTokens.FX_DISSOLVE_CELL * _px_scale)
