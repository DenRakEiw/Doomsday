extends GutTest
## S3.3, S4.4 — the containment panel and the discovery moment in a running
## session (spec m3-screens.md §4, §5; opposition.md §9.2).

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const ContainmentPanel: GDScript = preload("res://ui/panels/containment_panel.gd")
const DiscoveryModal: GDScript = preload("res://ui/modals/discovery_modal.gd")
const SEED: int = 1

var _session: Control = null
var _panel: ContainmentPanel = null
var _modals: ModalHost = null
var _discovery: DiscoveryModal = null
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	Game.stop_run()
	Game.debug_log = false
	_session = SESSION.instantiate()
	add_child_autofree(_session)
	_panel = _session.get_node("PanelLayer/ContainmentPanel")
	_modals = _session.get_node("ModalLayer/ModalHost")
	_discovery = _session.get_node("ModalLayer/ModalHost/DiscoveryModal")


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)
	Game.stop_run()


## A player's run — the discovery modal is for players, not for bots.
func _start() -> void:
	Game.start_run(SEED)
	Game.apply(ChooseOriginCommand.new(Game.db.regions[1].id))


func _label(name_text: String) -> Label:
	return _panel.get_node("%" + name_text) as Label


func test_shows_risk_before_and_tracks_after_discovery() -> void:
	_start()
	_panel.open()
	assert_true(_label("RiskLine").visible, "the risk is what an undiscovered run has")
	assert_true(_label("NotYet").visible)
	assert_null(_panel.get_node_or_null("%DriversBlock"), "the drivers block is gone")
	for track: Node in (_panel.get_node("%Tracks") as Node).get_children():
		assert_false((track.get_node("%Detail") as Control).visible,
			"nothing feeds a track before discovery")
	assert_string_contains(_label("RiskLine").text, "%")

	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 12
	_panel.refresh()
	assert_false(_label("RiskLine").visible)
	for track: Node in (_panel.get_node("%Tracks") as Node).get_children():
		assert_true((track.get_node("%Detail") as Control).visible,
			"and what feeds each track is what a discovered one has")
	assert_true(_label("Cause").visible)
	var chip: Chip = _panel.get_node("%StatusChip") as Chip
	assert_eq(chip.kind, Chip.Kind.ALERT)


func test_the_panel_shows_one_track_per_faction() -> void:
	_start()
	_panel.open()
	var tracks: VBoxContainer = _panel.get_node("%Tracks") as VBoxContainer
	assert_eq(tracks.get_child_count(), 4)
	for i: int in tracks.get_child_count():
		var glyph: GlyphIcon = tracks.get_child(i).get_node("%TrackGlyph") as GlyphIcon
		assert_eq(glyph.glyph, Glyphs.faction(Faction.FACTION_IDS[i]), "in faction order")


func test_each_track_shows_its_capacity_brakes_daily_and_terms() -> void:
	_start()
	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 1
	Game.sim.world.regions[1].penetration = 0.6
	Game.sim.world.faction("governments").containment = 0.3
	# Footprint nobody in particular watches: every faction sees some of it.
	var loud: Array[ModifierDef] = [ModifierDef.new()]
	loud[0].target = "footprint"
	loud[0].op = ModifierDef.Op.ADD
	loud[0].value = 4.0
	var no_flags: Array[String] = []
	Game.sim.world.modifiers.add_source("test_loud", loud, no_flags)
	_panel.open()
	var tracks: VBoxContainer = _panel.get_node("%Tracks") as VBoxContainer
	for i: int in tracks.get_child_count():
		var track: Node = tracks.get_child(i)
		var id: String = Faction.FACTION_IDS[i]
		var breakdown: Dictionary = Game.sim.containment_breakdown(id)
		assert_string_contains((track.get_node("%Capacity") as Label).text,
			Format.percent(float(breakdown[ContainmentSystem.CAPACITY])), id)
		assert_string_contains((track.get_node("%Daily") as Label).text,
			Format.percent_fine(float(breakdown[ContainmentSystem.GAIN])), id)
		assert_true((track.get_node("%TermA") as Label).visible, "%s has a term above 0" % id)
		assert_eq((track.get_node("%Leading") as Control).visible, id == "governments",
			"only the leader is marked")


func test_the_two_side_panels_never_overlap() -> void:
	_start()
	_panel.open()
	assert_true(_panel.is_open)
	EventBus.region_selected.emit(1)
	assert_false(_panel.is_open, "selecting a region closes the containment panel")


func test_discovery_holds_and_shows_the_modal() -> void:
	_start()
	Game.set_speed(2)
	EventBus.sim_event.emit(SimEvent.new(SimEvent.DISCOVERED, 40,
		{"cause": SimEvent.CAUSE_SCRUTINY}))
	assert_true(Game.is_held(), "the world waits while the player reads")
	assert_true(_modals.is_open())
	assert_eq(_modals.current(), _discovery)

	_discovery.dismissed.emit()
	assert_false(Game.is_held())
	assert_eq(Game.speed, 2, "and the speed comes back")


func test_a_bot_run_shows_no_modal() -> void:
	Game.start_run(SEED, GreedyPolicy.ID)
	EventBus.sim_event.emit(SimEvent.new(SimEvent.DISCOVERED, 40,
		{"cause": SimEvent.CAUSE_SCRUTINY}))
	assert_false(_modals.is_open(), "a bot run is narrated by the ticker alone")
	assert_false(Game.is_held())


func test_the_primary_button_opens_the_panel() -> void:
	_start()
	EventBus.sim_event.emit(SimEvent.new(SimEvent.DISCOVERED, 40,
		{"cause": SimEvent.CAUSE_DEATHS}))
	_discovery.containment_requested.emit()
	assert_false(_modals.is_open())
	assert_true(_panel.is_open)
	assert_false(Game.is_held())
