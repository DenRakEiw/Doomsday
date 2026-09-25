extends GutTest
## S6.1 — the full-screen pass (spec polish-visuals.md §3–§6): where it sits,
## when it shows, and what starts its impulses, wash and dissolve.
##
## Each test builds its own pass from the autoload's script, so the impulse
## cooldown and the flash limiter start fresh; the layer test reads the real one.

const ScreenFxScript: GDScript = preload("res://game/autoload/screen_fx.gd")

var _fx: CanvasLayer = null
var _reduced_motion: bool = false
var _screen_effects: float = 1.0


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_screen_effects = Settings.screen_effects
	Settings.set_reduced_motion(false)
	Settings.set_screen_effects(UiTokens.FX_INTENSITY_DESKTOP)
	_fx = ScreenFxScript.new()
	add_child_autofree(_fx)


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Settings.set_screen_effects(_screen_effects)


func test_layer_is_above_popups() -> void:
	var global: CanvasLayer = get_tree().root.get_node("ScreenFx") as CanvasLayer
	assert_not_null(global, "the autoload exists")
	assert_eq(global.layer, UiTokens.FX_LAYER)
	assert_gt(global.layer, 1024, "Window popups draw at 1024")


func test_pass_ignores_the_mouse() -> void:
	var rect: ColorRect = _fx.call(&"pass_rect") as ColorRect
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_off_hides_the_pass() -> void:
	assert_true(bool(_fx.call(&"is_shown")), "Full shows it")
	Settings.set_screen_effects(0.0)
	assert_false(bool(_fx.call(&"is_shown")))


func test_wash_shows_the_pass_at_off() -> void:
	Settings.set_screen_effects(0.0)
	_fx.call(&"flash_alert")
	assert_gt(float(_fx.call(&"wash_alpha")), 0.0)
	assert_true(bool(_fx.call(&"is_shown")), "the discovery moment is not decoration")


func test_wash_is_skipped_under_reduced_motion() -> void:
	Settings.set_reduced_motion(true)
	_fx.call(&"flash_alert")
	assert_eq(float(_fx.call(&"wash_alpha")), 0.0)


func test_second_wash_within_the_gap_is_refused() -> void:
	_fx.call(&"flash_alert")
	var first: Variant = _fx.call(&"wash_alpha")
	_fx.set(&"_wash_alpha", 0.0)
	_fx.call(&"flash_alert")
	assert_gt(float(first), 0.0)
	assert_eq(float(_fx.call(&"wash_alpha")), 0.0, "the flash limiter refused it")


func test_impulse_within_cooldown_is_ignored() -> void:
	_fx.call(&"impulse", 0.6)
	_fx.set(&"_impulse", 0.3)
	_fx.call(&"impulse", 0.2)
	assert_almost_eq(float(_fx.call(&"impulse_strength")), 0.3, 1e-6,
		"a weaker impulse inside the cooldown changes nothing")


func test_stronger_impulse_within_cooldown_replaces() -> void:
	_fx.call(&"impulse", 0.4)
	var started: int = int(_fx.get(&"_impulse_at"))
	_fx.call(&"impulse", 1.0)
	assert_almost_eq(float(_fx.call(&"impulse_strength")), 1.0, 1e-6)
	assert_eq(int(_fx.get(&"_impulse_at")), started, "the cooldown is not restarted")


func test_dissolve_starts_from_the_ground() -> void:
	_fx.call(&"dissolve_in")
	assert_almost_eq(float(_fx.call(&"dissolve_value")), 1.0, 1e-6)
	assert_true(bool(_fx.call(&"is_shown")))


func test_dissolve_reduced_motion_is_a_cut() -> void:
	Settings.set_reduced_motion(true)
	Settings.set_screen_effects(0.0)
	_fx.call(&"dissolve_in")
	assert_eq(float(_fx.call(&"dissolve_value")), 0.0)
	assert_false(bool(_fx.call(&"is_shown")))


func test_discovery_event_starts_an_impulse() -> void:
	EventBus.sim_event.emit(SimEvent.new(SimEvent.DISCOVERED, 1, {}))
	assert_almost_eq(float(_fx.call(&"impulse_strength")), ScreenFxRules.IMPULSE_FULL, 1e-6)


func test_reduced_motion_draws_no_aberration() -> void:
	Settings.set_reduced_motion(true)
	_fx.call(&"impulse", 1.0)
	var params: ScreenFxParams = _fx.call(&"params") as ScreenFxParams
	assert_eq(params.ca_scale, 0.0)
