extends GutTest
## S3.3 — what the interface shows in each phase (spec m3-screens.md §6.1) and
## the one palette change (§6.2).
##
## Reveal is a function of the state, so every case here sets a phase and asks
## the HUD what it shows — no event sequence is needed to get there.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
const TARGET_HARM: String = "harm"

var _session: Control = null
var _hud: Control = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_hud = _session.get_node("HudLayer/SafeArea/Hud")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	UiTokens.variant = UiTokens.VARIANT_COLD
	Game.stop_run()


func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func _block(path: String) -> Control:
	return _hud.get_node("%" + path) as Control


func _bar(name_text: String) -> Control:
	return _block("StatRow").get_node("%" + name_text) as Control


func _dock_button(index: int) -> Control:
	var column: VBoxContainer = _block("Dock").get_node("%Column") as VBoxContainer
	return column.get_child(index) as Control


func _set_phase(phase: World.Phase) -> void:
	Game.sim.world.phase = phase
	_hud.call(&"apply_reveal")


func test_reveal_follows_the_table() -> void:
	_start()
	_set_phase(World.Phase.BOXED)
	assert_true(_bar("Penetration").visible, "one bar is what Boxed has")
	assert_false(_bar("Footprint").visible)
	assert_false(_bar("Harm").visible)
	assert_false(_block("OverlayPicker").visible)
	assert_true(_dock_button(0).visible, "and one dock button")
	assert_false(_dock_button(1).visible)
	assert_false(_dock_button(2).visible)

	_set_phase(World.Phase.COVERT)
	assert_true(_bar("Footprint").visible)
	assert_false(_bar("Harm").visible, "no harm yet, no harm bar")
	assert_true(_block("OverlayPicker").visible)
	assert_true(_dock_button(1).visible, "containment is the Covert player's tool")
	assert_false(_dock_button(2).visible)

	_set_phase(World.Phase.EMERGENT)
	assert_true(_bar("Harm").visible, "from Emergent it is always there")
	assert_false(_dock_button(2).visible)

	_set_phase(World.Phase.OPEN)
	assert_true(_dock_button(2).visible, "analysis appears in Open, disabled")
	assert_true((_dock_button(2) as Button).disabled)


func test_the_harm_bar_appears_with_the_first_harm() -> void:
	_start()
	_set_phase(World.Phase.COVERT)
	assert_false(_bar("Harm").visible)
	# The stat itself, not a particular node: what the rule reads is
	# `stat("harm")`, and which node raises it is content (§6.1).
	var harm: ModifierDef = ModifierDef.new()
	harm.target = TARGET_HARM
	harm.op = ModifierDef.Op.ADD
	harm.value = 1.0
	var modifiers: Array[ModifierDef] = [harm]
	var no_flags: Array[String] = []
	Game.sim.world.modifiers.add_source("test_harm", modifiers, no_flags)
	_hud.call(&"apply_reveal")
	assert_true(_bar("Harm").visible, "the bar is there the moment there is harm")


## S3.P, from G3: the reveal reads the maximum over the regions, so a player
## who owns only scoped Harm gets the bar too (§6.1).
func test_a_scoped_harm_node_reveals_the_bar_too() -> void:
	_start()
	_set_phase(World.Phase.COVERT)
	assert_false(_bar("Harm").visible)
	var harm: ModifierDef = ModifierDef.new()
	harm.target = TARGET_HARM
	harm.op = ModifierDef.Op.ADD
	harm.value = 1.0
	harm.scope_kind = ModifierDef.ScopeKind.REGION
	harm.scope_region = Game.sim.world.agent.origin
	var modifiers: Array[ModifierDef] = [harm]
	var no_flags: Array[String] = []
	Game.sim.world.modifiers.add_source("test_scoped_harm", modifiers, no_flags)
	assert_eq(Game.sim.world.modifiers.value(TARGET_HARM), 0.0,
		"the unscoped stat the HUD used to read is still 0")
	_hud.call(&"apply_reveal")
	assert_true(_bar("Harm").visible, "one region is harmed, so the bar is there")


func test_open_swaps_the_variant_once() -> void:
	_start()
	assert_eq(String(UiTokens.variant), String(UiTokens.VARIANT_COLD))
	_set_phase(World.Phase.OPEN)
	assert_eq(String(UiTokens.variant), String(UiTokens.VARIANT_OPEN))
	var theme: Theme = (_session as Control).theme
	assert_eq(theme.get_color("font_color", "Label"), UiTokens.OPEN[&"TEXT_0"],
		"the session's theme is the open one")

	Game.start_run(SEED + 1)
	assert_eq(String(UiTokens.variant), String(UiTokens.VARIANT_COLD),
		"a new run is cold again")


func test_a_loaded_run_shows_its_phase_at_once() -> void:
	_start()
	Game.sim.world.phase = World.Phase.OPEN
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 30
	# What a load does: adopt the simulation and tell the interface once.
	EventBus.run_started.emit(SEED)
	_hud.call(&"apply_reveal")
	assert_true(_bar("Harm").visible)
	assert_true(_dock_button(2).visible)
	assert_eq(String(UiTokens.variant), String(UiTokens.VARIANT_OPEN))
