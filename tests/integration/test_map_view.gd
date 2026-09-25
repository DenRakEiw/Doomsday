extends GutTest
## S2.2 — the map view as it is wired into a run (spec ui-foundation.md §7.1–§7.3).
##
## What the shader receives is read back from the material, so the test checks
## the uniforms rather than what the script believes it sent. The one exception
## is the data row: headless, an `ImageTexture` gives back the image it was
## created with and not the one `update` uploaded, so the pixels are read from
## the view's own image.

const MAP_VIEW: PackedScene = preload("res://game/map/map_view.tscn")
const SEED: int = 1
## Far enough for `greedy` to hold an origin and to have spread from it.
const WARMUP_DAYS: int = 40

var _view: MapView
var _material: ShaderMaterial


func before_each() -> void:
	Game.stop_run()
	Game.debug_log = false
	_view = MAP_VIEW.instantiate()
	add_child_autofree(_view)
	_material = _view.material as ShaderMaterial


func after_all() -> void:
	Game.stop_run()


func _data_image() -> Image:
	return _view.data_image()


func test_the_quad_is_the_id_map_at_one_to_one_from_the_origin() -> void:
	assert_false(_view.centered, "the top-left corner is the world origin")
	assert_eq(_view.texture.get_width(), 4096)
	assert_eq(_view.texture.get_height(), 2048)


func test_the_shader_gets_its_three_map_textures() -> void:
	for param: String in ["id_map", "land_mask", "border_mask"]:
		assert_not_null(_material.get_shader_parameter(param), param)


func test_the_data_texture_is_the_row_the_spec_describes() -> void:
	var texture: Texture2D = _material.get_shader_parameter("region_data")
	assert_not_null(texture, "the row exists before the first tick")
	assert_eq(texture.get_width(), RegionData.WIDTH)
	assert_eq(texture.get_height(), RegionData.HEIGHT)


func test_the_palette_comes_from_the_tokens_and_not_from_the_shader() -> void:
	assert_eq(_material.get_shader_parameter("map_land"), UiTokens.MAP_LAND)
	assert_eq(_material.get_shader_parameter("map_dark"), UiTokens.MAP_DARK)
	assert_eq(_material.get_shader_parameter("map_death"), UiTokens.MAP_DEATH)
	assert_eq(_material.get_shader_parameter("hover_gain"), UiTokens.MAP_HOVER_GAIN)
	# G2: the overlay's strength was a literal in the shader, and a half-taken
	# world outshone the HUD (§7.3).
	assert_eq(_material.get_shader_parameter("overlay_mix"), UiTokens.MAP_OVERLAY_MIX)
	assert_not_null(_material.get_shader_parameter("ramp"), "and so does the ramp")


func test_a_tick_writes_the_spread_into_the_data_texture() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(WARMUP_DAYS)
	var origin: int = Game.sim.world.agent.origin
	assert_gt(origin, 0, "the bot chose an origin")

	var pixel: Color = _data_image().get_pixel(origin, 0)
	assert_almost_eq(pixel.r, Game.sim.world.regions[origin].penetration, 1.5 / 255.0,
		"the origin's penetration reached the texture")
	assert_eq(RegionData.flags_of(pixel) & RegionData.FLAG_SEEDED, RegionData.FLAG_SEEDED)


func test_the_texture_object_is_updated_and_never_replaced() -> void:
	var before: Texture2D = _material.get_shader_parameter("region_data")
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(WARMUP_DAYS)
	assert_same(_material.get_shader_parameter("region_data"), before,
		"the shader keeps the texture it was given; only its pixels change")


func test_without_a_run_the_row_is_empty() -> void:
	var image: Image = _data_image()
	for i: int in [0, 1, 2, RegionData.WIDTH - 1]:
		assert_eq(image.get_pixel(i, 0).a, 0.0, "pixel %d" % i)


# ------------------------------------------------- S6.2 (polish-visuals §9, §10)


func test_the_society_view_gets_its_colour_and_stage_count() -> void:
	assert_eq(_material.get_shader_parameter("map_society"), UiTokens.MAP_SOCIETY)
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(1)
	assert_eq(_material.get_shader_parameter("society_stage_max"),
		float(Game.db.balance.society_stage_thresholds.size()))


func test_the_society_overlay_reaches_the_shader() -> void:
	EventBus.overlay_changed.emit(int(MapView.Overlay.SOCIETY))
	assert_eq(_view.overlay_mode, MapView.Overlay.SOCIETY)
	assert_eq(_material.get_shader_parameter("overlay_mode"), int(MapView.Overlay.SOCIETY))


func test_the_outline_is_smooth_from_the_switch_zoom_on() -> void:
	assert_eq(_material.get_shader_parameter("outline_mask"), UiTokens.MAP_OUTLINE_MASK)
	_view.call(&"_on_camera_view_changed", Vector2.ZERO, UiTokens.MAP_SMOOTH_OUTLINE_ZOOM)
	assert_true(_material.get_shader_parameter("smooth_outline"))
	_view.call(&"_on_camera_view_changed", Vector2.ZERO,
		UiTokens.MAP_SMOOTH_OUTLINE_ZOOM * 0.5)
	assert_false(_material.get_shader_parameter("smooth_outline"),
		"below the switch a texel is under two screen pixels and the taps are exact")
