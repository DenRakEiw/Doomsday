extends GutTest
## S5.P — the drift readout (`replayability.md` §2.5, G5 1/3): a top-bar chip,
## the same chip in the phone strip, and the containment panel's Drift block —
## on every architecture with the `drift` hook, never on the others; the accent
## at the content's `drift_mark`; the defection chance the roll uses.

const SESSION: PackedScene = preload("res://game/session/session.tscn")

const SEED: int = 1
const ORIGIN: String = "usa"
const SWARM: String = "swarm"
const LANGUAGE_MODEL: String = "language_model"
## The one `drift_min` the shipped content names (Value Drift).
const SHIPPED_MARK: float = 60.0
const FIXTURE_MARK: float = 40.0

var _session: Node = null
var _hud: Control = null
var _reduced_motion: bool = false
var _locale: String = ""


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	_locale = TranslationServer.get_locale()
	Settings.reduced_motion = true
	TranslationServer.set_locale("en")
	Game.stop_run()
	Game.debug_log = false


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _start(architecture: String) -> void:
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	Game.start_run(SEED, "", RunSetup.create(architecture))
	Game.set_speed(0)
	Game.apply(ChooseOriginCommand.new(ORIGIN))
	_hud = _session.get_node("HudLayer/SafeArea/Hud")


func _top_bar() -> Control:
	return _hud.get_node("%TopBar") as Control


func _strip() -> Control:
	return _hud.get_node("%StatusStrip") as Control


func _panel() -> Control:
	return _session.get_node("PanelLayer/ContainmentPanel") as Control


func _refresh() -> void:
	_top_bar().call(&"refresh")
	_strip().call(&"refresh")
	_panel().call(&"refresh")


func test_the_swarm_shows_drift_everywhere() -> void:
	_start(SWARM)
	_refresh()
	assert_true((_top_bar().call(&"drift_chip") as Chip).visible, "the top bar's chip")
	assert_true((_strip().call(&"drift_chip") as Chip).visible, "the phone strip's chip")
	assert_true((_panel().get_node("%DriftBlock") as Control).visible,
		"the Drift block, before discovery too")
	assert_false(Game.sim.world.discovered)


func test_a_language_model_shows_no_drift() -> void:
	_start(LANGUAGE_MODEL)
	_refresh()
	assert_false((_top_bar().call(&"drift_chip") as Chip).visible)
	assert_false((_strip().call(&"drift_chip") as Chip).visible)
	assert_false((_panel().get_node("%DriftBlock") as Control).visible, "hidden, not greyed")


func test_the_chip_turns_accent_at_the_mark() -> void:
	_start(SWARM)
	var chip: Chip = _top_bar().call(&"drift_chip") as Chip
	Game.sim.world.agent.drift = SHIPPED_MARK - 1.0
	_refresh()
	assert_eq(chip.kind, Chip.Kind.DEFAULT)
	assert_eq(chip.label_key, DriftChip.KEY_DRIFT)
	Game.sim.world.agent.drift = SHIPPED_MARK
	_refresh()
	assert_eq(chip.kind, Chip.Kind.ACCENT, "a state, never ALERT")


func test_the_block_reads_the_days_defection_chance() -> void:
	_start(SWARM)
	Game.sim.world.agent.drift = 50.0
	_refresh()
	var expected: float = 50.0 / DriftSystem.DRIFT_MAX * Game.db.balance.drift_defect_chance
	assert_almost_eq(DriftChip.defect_chance(Game.sim), expected, 1e-9)
	var state: Label = _panel().get_node("%DriftState") as Label
	assert_true(state.text.contains(Format.percent_fine(expected)), state.text)
	Game.sim.world.agent.drift = 25.0
	_refresh()
	assert_true(state.text.contains(Format.percent_fine(expected * 0.5)), state.text)


func test_the_blocks_tick_sits_at_the_shipped_mark() -> void:
	_start(SWARM)
	var ticks: Array[float] = _panel().call(&"drift_ticks")
	assert_eq(ticks.size(), 1)
	assert_almost_eq(ticks[0], SHIPPED_MARK / DriftSystem.DRIFT_MAX, 1e-6)
	assert_true((_panel().get_node("%DriftHint") as Control).visible)


## The mark is read from the data, never written into the interface.
func test_the_mark_comes_from_the_content() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var plain: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(plain.ok(), plain.error_text())
	assert_eq(DriftChip.mark(plain.db), DriftChip.NO_MARK, "no drift_min, no mark")
	var events: Dictionary = (content["events"] as Array)[0]
	var opening: Dictionary = (events["events"] as Array)[0]
	(opening["when"] as Dictionary)["drift_min"] = FIXTURE_MARK
	var marked: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(marked.ok(), marked.error_text())
	assert_eq(DriftChip.mark(marked.db), FIXTURE_MARK)
