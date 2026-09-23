extends GutTest
## S4.4 — the threat bar (opposition.md §9.1): hidden while Boxed, the daily
## discovery risk in Covert, the leading faction once they know — in its colour,
## with its glyph — and the same on the phone's strip.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1

var _session: Control = null
var _hud: Control = null
var _console: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_hud = _session.get_node("HudLayer/SafeArea/Hud")
	_console = _hud.get_node("%ConsoleLine") as Control


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func _row() -> Control:
	return _hud.get_node("%StatRow") as Control


func _threat() -> StatBar:
	return _row().get_node("%Threat") as StatBar


func _set_phase(phase: World.Phase) -> void:
	Game.sim.world.phase = phase
	_hud.call(&"apply_reveal")


func _refresh() -> void:
	_row().call(&"refresh")


func test_the_bar_is_hidden_while_boxed_and_shown_from_covert() -> void:
	_start()
	_set_phase(World.Phase.BOXED)
	assert_false(_threat().visible)
	_set_phase(World.Phase.COVERT)
	assert_true(_threat().visible)


func test_before_discovery_it_shows_the_risk() -> void:
	_start()
	_set_phase(World.Phase.COVERT)
	_refresh()
	var bar: StatBar = _threat()
	assert_eq(bar.theme_type_variation, UiTokens.STAT_BAR_RISK)
	assert_eq(bar.label_key, "UI_TERM_RISK")
	assert_false((bar.get_node("%Glyph") as Control).visible, "no faction yet, no glyph")
	var risk: float = float(Game.sim.discovery_risk()[ContainmentSystem.RISK_TOTAL])
	assert_almost_eq(bar.value(), minf(1.0, risk / UiTokens.RISK_BAR_MAX), 1e-6)
	assert_string_contains((bar.get_node("%Value") as Label).text,
		Format.percent_fine(risk), "the fine percent, one decimal")


func test_after_discovery_it_shows_the_leader_in_its_colour() -> void:
	_start()
	_set_phase(World.Phase.EMERGENT)
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 1
	Game.sim.world.faction("public_sentiment").containment = 0.4
	_refresh()
	var bar: StatBar = _threat()
	assert_eq(bar.theme_type_variation, &"StatBarPublic")
	assert_eq(bar.label_key, "FACTION_PUBLIC_SENTIMENT")
	var glyph: GlyphIcon = bar.get_node("%Glyph") as GlyphIcon
	assert_true(glyph.visible)
	assert_eq(glyph.glyph, Glyphs.Glyph.FACTION_PUBLIC)
	assert_almost_eq(bar.value(), 0.4, 1e-6)
	assert_eq(bar.ticks.size(), Game.db.balance.containment_thresholds.size() + 1,
		"the thresholds and the end, as on the panel")


func test_a_new_leader_swaps_the_face_and_says_so() -> void:
	_start()
	_set_phase(World.Phase.EMERGENT)
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 1
	Game.sim.world.faction("governments").containment = 0.3
	_refresh()
	assert_eq(_threat().theme_type_variation, &"StatBarGovernments")
	_console.call(&"clear")
	Game.sim.world.faction("ai_labs").containment = 0.5
	EventBus.sim_event.emit(SimEvent.new(SimEvent.THREAT_LEADER_CHANGED, Game.sim.world.day,
		{"from": "governments", "to": "ai_labs"}))
	assert_eq(_threat().theme_type_variation, &"StatBarAiLabs")
	var said: int = int(_console.call(&"queued")) + (1 if bool(_console.call(&"is_showing")) else 0)
	assert_eq(said, 1, "the console names the new leader")


func test_the_phone_strip_carries_the_same_readout() -> void:
	_start()
	_set_phase(World.Phase.COVERT)
	var strip: Control = _hud.get_node("%StatusStrip") as Control
	strip.call(&"refresh")
	var caption: Control = strip.get(&"_threat_caption") as Control
	var glyph: GlyphIcon = strip.get(&"_threat_glyph") as GlyphIcon
	assert_true(caption.visible, "Risk over the fine percent before discovery")
	assert_false(glyph.visible)
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 1
	Game.sim.world.faction("security_researchers").containment = 0.2
	strip.call(&"refresh")
	assert_false(caption.visible)
	assert_true(glyph.visible)
	assert_eq(glyph.glyph, Glyphs.Glyph.FACTION_RESEARCHERS)
	var value: ValueLabel = strip.get(&"_threat_value") as ValueLabel
	assert_string_contains(value.text, Format.percent(0.2))


## S4.9: the rate string carried a `+` of its own in front of the value label's
## sign, and the screenshots showed `+±0 % / Tag`.
func test_the_rate_carries_one_sign() -> void:
	_start()
	_set_phase(World.Phase.EMERGENT)
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 1
	Game.sim.world.faction("public_sentiment").containment = 0.4
	_refresh()
	var shown: String = (_threat().get_node("%Value") as Label).text
	for doubled: String in ["+±", "+▲", "+▼", "++"]:
		assert_false(shown.contains(doubled), shown)
