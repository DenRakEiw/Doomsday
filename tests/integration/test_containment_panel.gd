extends GutTest
## S3.3 — the containment panel and the discovery moment in a running session
## (spec m3-screens.md §4, §5).

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
	assert_false((_panel.get_node("%DriversBlock") as Control).visible)
	assert_string_contains(_label("RiskLine").text, "%")

	Game.sim.world.discovered = true
	Game.sim.world.discovery_day = 12
	_panel.refresh()
	assert_false(_label("RiskLine").visible)
	assert_true((_panel.get_node("%DriversBlock") as Control).visible,
		"and the drivers are what a discovered one has")
	assert_true(_label("Cause").visible)
	var chip: Chip = _panel.get_node("%StatusChip") as Chip
	assert_eq(chip.kind, Chip.Kind.ALERT)


func test_the_panel_shows_one_track_per_faction() -> void:
	_start()
	_panel.open()
	var tracks: VBoxContainer = _panel.get_node("%Tracks") as VBoxContainer
	assert_eq(tracks.get_child_count(), Game.sim.world.factions.size())


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
