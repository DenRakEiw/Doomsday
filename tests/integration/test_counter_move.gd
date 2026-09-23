extends GutTest
## S4.5 — a counter-move in a hand-driven session on `res://data`
## (opposition.md §15.2): the governments pushed to 0.3 prepare a Lockdown, the
## panel counts it down, it lands on the only region the agent holds, and the
## answers read as the card says. Also the Society row, the starving chip and
## the wire card's faction glyph.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
const ORIGIN: String = "usa"
const GOVERNMENTS: String = "governments"
const LOCKDOWN: String = "cm_lockdown"
const PERSISTENCE: String = "host_persistence"

var _session: Control = null
var _panel: SlidePanel = null
var _containment: SlidePanel = null
var _wire: WireCard = null
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
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_panel = _session.get_node("%RegionPanel") as SlidePanel
	_containment = _session.get_node("PanelLayer/ContainmentPanel") as SlidePanel
	_wire = _session.get_node("%WireCard") as WireCard
	_hud = _session.get_node("HudLayer/SafeArea/Hud")
	Game.start_run(SEED)
	Game.set_speed(0)
	assert_true(Game.apply(ChooseOriginCommand.new(ORIGIN)).ok)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _origin() -> int:
	return Game.db.region_index_by_id[ORIGIN]


## Discovered, the governments at 0.3 and everyone else quiet.
func _push_governments() -> Faction:
	var world: World = Game.sim.world
	world.discovered = true
	world.discovery_day = world.day
	Fixtures.quiet_factions(Game.sim)
	var governments: Faction = world.faction(GOVERNMENTS)
	governments.cooldown_until = 0
	governments.containment = 0.3
	return governments


func _advance_until_open(def_id: String) -> OpenEvent:
	for i: int in 80:
		for event: OpenEvent in Game.sim.world.events:
			if event.def == def_id:
				return event
		Game.advance(1)
	fail_test("%s never opened" % def_id)
	return null


func _card() -> EventCard:
	return _panel.call(&"event_card") as EventCard


func test_a_lockdown_is_announced_counted_down_and_lands() -> void:
	var governments: Faction = _push_governments()
	Game.advance(1)
	assert_eq(governments.preparing, LOCKDOWN)
	var next: Dictionary = Game.sim.next_move(GOVERNMENTS)
	assert_eq(next["state"], "preparing")
	assert_eq(int(next["days"]), governments.fire_day - Game.sim.world.day)

	_containment.call(&"open")
	var tracks: Node = _containment.get_node("%Tracks")
	var chip: Chip = tracks.get_child(1).get_node("%NextChip") as Chip
	assert_true((tracks.get_child(1).get_node("%Next") as Control).visible,
		"the countdown is on the panel")
	assert_eq(chip.label_key, "UI_CONTAINMENT_NEXT_PREPARING")

	var event: OpenEvent = _advance_until_open(LOCKDOWN)
	assert_eq(event.region, _origin(), "the only region the agent holds")
	assert_eq(event.faction, GOVERNMENTS)
	EventBus.region_selected.emit(_origin())
	var options: EventOptions = _card().options()
	assert_false(options.button_of("ride").disabled, "the free answer")
	assert_true(options.button_of("persist").disabled, "Dig in needs a persistence node")
	assert_true(options.button_of("lobby").disabled, "a favour needs Lobby")

	var before: float = Game.sim.world.regions[_origin()].penetration
	options.button_of("ride").pressed.emit()
	var lockdown: Status = Game.sim.world.status_in_region("lockdown", _origin())
	assert_not_null(lockdown, "riding it out seals the region")
	assert_eq(Status.faction_of(lockdown.source), GOVERNMENTS)
	Game.advance(1)
	assert_lt(Game.sim.world.regions[_origin()].penetration, before, "and it bleeds")

	var until: int = lockdown.until_day
	while Game.sim.world.day < until:
		Game.advance(1)
	assert_null(Game.sim.world.status_in_region("lockdown", _origin()),
		"it ends on the day the status said")


func test_dig_in_with_persistence_costs_four_and_holds() -> void:
	Game.sim.world.agent.owned_nodes.append(PERSISTENCE)
	Game.sim.rebuild_modifiers()
	Fixtures.grant(Game.sim, 20.0)
	_push_governments()
	var event: OpenEvent = _advance_until_open(LOCKDOWN)
	EventBus.region_selected.emit(event.region)
	var options: EventOptions = _card().options()
	assert_false(options.button_of("persist").disabled)
	var compute: float = Game.sim.world.agent.compute
	options.button_of("persist").pressed.emit()
	assert_almost_eq(Game.sim.world.agent.compute, compute - 4.0, 1e-9)
	assert_true(Game.sim.world.has_status("lockdown", event.region))
	assert_true(Game.sim.world.has_status("holding", event.region), "a second ring")


func test_the_society_row_shows_the_stage_and_the_cuts() -> void:
	EventBus.region_selected.emit(_origin())
	var block: Control = _panel.call(&"society_block") as Control
	assert_false(block.visible, "hidden at 0")
	Game.sim.world.regions[_origin()].society = 30.0
	_panel.call(&"refresh")
	assert_true(block.visible)
	var chip: Chip = null
	for node: Node in block.find_children("*", "PanelContainer", true, false):
		if node is Chip:
			chip = node
	assert_not_null(chip)
	assert_eq(chip.label_key, "SOCIETY_STAGE_2")
	assert_eq(chip.kind, Chip.Kind.ACCENT)


func test_the_starving_chip_counts_down_and_turns_red() -> void:
	var top_bar: Control = _hud.get_node("%TopBar") as Control
	var chip: Chip = top_bar.call(&"starving_chip") as Chip
	Game.sim.world.starving_days = 1
	top_bar.call(&"refresh")
	assert_true(chip.visible)
	assert_eq(chip.kind, Chip.Kind.DEFAULT)
	Game.sim.world.starving_days = Game.db.balance.society_autophagy_days - 3
	top_bar.call(&"refresh")
	assert_eq(chip.kind, Chip.Kind.ALERT, "the last days are a moment")
	Game.sim.world.starving_days = 0
	top_bar.call(&"refresh")
	assert_false(chip.visible, "income ends it")


func test_a_global_move_shows_the_factions_glyph() -> void:
	EventSystem.schedule(Game.sim.world, "cm_disclosure_network", 0,
		"security_researchers", Game.sim.world.day + 1, 1)
	Game.advance(1)
	assert_true(_wire.visible)
	var slot: IllustrationSlot = _wire.call(&"illustration") as IllustrationSlot
	assert_eq(slot.fallback_glyph().glyph, Glyphs.Glyph.FACTION_RESEARCHERS)
