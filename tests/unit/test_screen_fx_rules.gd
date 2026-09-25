extends GutTest
## S6.1 — the rules of the full-screen pass (spec polish-visuals.md §3.6, §3.7,
## §4.1): heat, the parameters at a setting, and the impulses of events.


func test_heat_boxed_is_zero() -> void:
	assert_eq(ScreenFxRules.heat(World.Phase.BOXED, 1.0), 0.0,
		"Boxed is clinical whatever the endgame says")


func test_heat_rises_with_phase() -> void:
	var boxed: float = ScreenFxRules.heat(World.Phase.BOXED, 0.0)
	var covert: float = ScreenFxRules.heat(World.Phase.COVERT, 0.0)
	var emergent: float = ScreenFxRules.heat(World.Phase.EMERGENT, 0.0)
	var open: float = ScreenFxRules.heat(World.Phase.OPEN, 0.0)
	assert_lt(boxed, covert)
	assert_lt(covert, emergent)
	assert_lt(emergent, open)


func test_heat_open_reaches_one_at_endgame() -> void:
	assert_almost_eq(ScreenFxRules.heat(World.Phase.OPEN, UiTokens.FX_HEAT_ENDGAME.y), 1.0,
		1e-6)
	assert_almost_eq(ScreenFxRules.heat(World.Phase.OPEN, UiTokens.FX_HEAT_ENDGAME.x),
		UiTokens.FX_HEAT_PHASE[World.Phase.OPEN], 1e-6)


func test_endgame_takes_the_larger_of_containment_and_control() -> void:
	var simulation: Simulation = Fixtures.sim_with_containment("governments", 0.4)
	var world: World = simulation.world
	var db: ContentDB = simulation.db
	assert_almost_eq(ScreenFxRules.endgame(world, db), 0.4, 1e-6, "containment alone")
	# Every live region held: control is the larger term.
	for i: int in range(1, world.regions.size()):
		world.regions[i].control = db.balance.control_complete
	assert_almost_eq(ScreenFxRules.endgame(world, db), 1.0, 1e-6, "the world taken")


func test_params_off_disables_the_pass() -> void:
	var params: ScreenFxParams = ScreenFxRules.params(0.0, 1.0, false)
	assert_false(params.enabled)
	assert_eq(params.bloom_taps, 0)
	assert_eq(params.vignette, 0.0)
	assert_eq(params.grain_amp, 0.0)
	assert_eq(params.ca_scale, 0.0)


func test_params_reduced_motion_zeroes_scanlines_grain_and_ca() -> void:
	var params: ScreenFxParams = ScreenFxRules.params(1.0, 1.0, true)
	assert_true(params.enabled)
	assert_eq(params.scan_depth, 0.0)
	assert_eq(params.grain_amp, 0.0)
	assert_eq(params.ca_scale, 0.0)


func test_params_reduced_motion_keeps_bloom_vignette_dither() -> void:
	var still: ScreenFxParams = ScreenFxRules.params(1.0, 1.0, true)
	var moving: ScreenFxParams = ScreenFxRules.params(1.0, 1.0, false)
	assert_eq(still.bloom_strength, moving.bloom_strength)
	assert_eq(still.bloom_taps, moving.bloom_taps)
	assert_eq(still.vignette, moving.vignette)
	assert_eq(still.dither_levels, moving.dither_levels)
	assert_gt(still.vignette, 0.0)


func test_params_subtle_uses_eight_bloom_taps() -> void:
	assert_eq(ScreenFxRules.params(0.5, 0.0, false).bloom_taps, ScreenFxRules.BLOOM_TAPS_SUBTLE)
	assert_eq(ScreenFxRules.params(1.0, 0.0, false).bloom_taps, ScreenFxRules.BLOOM_TAPS_FULL)


func test_params_heat_coarsens_the_dither() -> void:
	var cold: ScreenFxParams = ScreenFxRules.params(1.0, 0.0, false)
	var hot: ScreenFxParams = ScreenFxRules.params(1.0, 1.0, false)
	assert_eq(cold.dither_levels, UiTokens.FX_DITHER_LEVELS.x)
	assert_eq(hot.dither_levels, UiTokens.FX_DITHER_LEVELS.y)
	assert_gt(hot.grain_amp, cold.grain_amp)


func test_impulse_for_discovery_is_full() -> void:
	assert_eq(_impulse(SimEvent.DISCOVERED, {}), ScreenFxRules.IMPULSE_FULL)


func test_impulse_for_open_phase_is_full() -> void:
	assert_eq(_impulse(SimEvent.PHASE_CHANGED, {"from": "emergent", "to": "open"}),
		ScreenFxRules.IMPULSE_FULL)


func test_impulse_for_other_phase_is_zero() -> void:
	assert_eq(_impulse(SimEvent.PHASE_CHANGED, {"from": "boxed", "to": "covert"}), 0.0)


func test_impulse_for_counter_move_event() -> void:
	var def_id: String = ""
	for def: EventDef in Fixtures.db().events:
		if def.kind == EventDef.KIND_COUNTER_MOVE:
			def_id = def.id
			break
	assert_ne(def_id, "", "the fixture has a counter-move")
	assert_eq(_impulse(SimEvent.EVENT_OPENED, {"def": def_id}),
		ScreenFxRules.IMPULSE_COUNTER_MOVE)
	assert_eq(_impulse(SimEvent.EVENT_OPENED, {"def": "", "kind": EventDef.KIND_OPENING}), 0.0,
		"an opening does not tear the frame")


func test_impulse_for_loss_is_stronger_than_win() -> void:
	var loss: float = _impulse(SimEvent.OUTCOME_REACHED, {"outcome": "lose_contained"})
	var win: float = _impulse(SimEvent.OUTCOME_REACHED, {"outcome": "win_extinction"})
	assert_gt(win, 0.0)
	assert_gt(loss, win)


func test_impulse_for_headline_is_zero() -> void:
	assert_eq(_impulse(SimEvent.HEADLINE, {}), 0.0)


func _impulse(type: String, data: Dictionary) -> float:
	return ScreenFxRules.impulse_for(SimEvent.new(type, 1, data), Fixtures.db())
