extends GutTest
## S4.3 — the map events in the interface: the marker, the region panel's event
## card, the wire card and the discovery modal's picture slot
## (`docs/specs/loop-mechanics.md` §16.3.2, §16.5 item 12, §16.7).
##
## The whole session on `res://data`, driven by hand with the clock stopped. An
## event is put on the map by scheduling it for tomorrow and advancing one day,
## so it arrives the way every event does — through the tick and the event bus.

const SESSION: PackedScene = preload("res://game/session/session.tscn")
const SEED: int = 1
const ORIGIN: String = "usa"
const OPENING: String = "opening_unattended_cluster"
## An opening with a locked option: *quiet* needs Personalised Persuasion.
const LOCKED_OPENING: String = "opening_ministry_demo"
## A global chain step that asks for the wire card.
const GLOBAL_EVENT: String = "gb_bill"
## S6.8: a counter-move and the faction that makes it.
const COUNTER_MOVE: String = "cm_lockdown"
const FACTION: String = "governments"

var _session: Control = null
var _layer: Node2D = null
var _camera: MapCamera = null
var _panel: SlidePanel = null
var _wire: WireCard = null
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
	_layer = _session.get_node("MapLayer/MarkerLayer") as Node2D
	_camera = _session.get_node("MapLayer/MapCamera") as MapCamera
	_panel = _session.get_node("%RegionPanel") as SlidePanel
	_wire = _session.get_node("%WireCard") as WireCard
	Game.start_run(SEED)
	Game.set_speed(0)
	assert_true(Game.apply(ChooseOriginCommand.new(ORIGIN)).ok)


func after_each() -> void:
	Settings.reduced_motion = _reduced_motion
	TranslationServer.set_locale(_locale)
	Game.stop_run()


func _index(region_id: String) -> int:
	return Game.db.region_index_by_id[region_id]


## Schedules `def_id` for tomorrow in `region_id` ("" = global) and lets the
## tick open it. Answers the open record.
func _arrive(def_id: String, region_id: String = ORIGIN) -> OpenEvent:
	var region: int = 0 if region_id.is_empty() else _index(region_id)
	EventSystem.schedule(Game.sim.world, def_id, region, "", Game.sim.world.day + 1, 1)
	Game.advance(1)
	for event: OpenEvent in Game.sim.world.events:
		if event.def == def_id:
			return event
	fail_test("%s did not open" % def_id)
	return null


func _card() -> EventCard:
	return _panel.call(&"event_card") as EventCard


## The screen point of a region's event marker.
func _event_point(region_id: String) -> Vector2:
	var anchor: Vector2 = Vector2(Game.sim.world.regions[_index(region_id)].def.anchor)
	_camera.set_view(anchor, 3.0)
	return _camera.canvas_transform() * anchor + UiTokens.MARKER_EVENT_OFFSET


# ------------------------------------------------------------------ the marker


func test_an_opening_puts_a_marker_on_its_region() -> void:
	assert_eq(_layer.call(&"event_count"), 0)
	var event: OpenEvent = _arrive(OPENING)
	assert_eq(_layer.call(&"event_count"), 1)
	var marker: EventMarker = _layer.call(&"event_marker_of", _index(ORIGIN)) as EventMarker
	assert_not_null(marker)
	assert_eq(marker.event_id, event.id)
	assert_eq(marker.kind, EventDef.KIND_OPENING)


func test_tapping_the_marker_opens_the_panel_on_its_card() -> void:
	var event: OpenEvent = _arrive(OPENING)
	assert_true(_layer.call(&"try_tap", _event_point(ORIGIN)))
	assert_eq(_panel.call(&"region_index"), _index(ORIGIN))
	assert_true(_card().visible)
	assert_eq(_card().event_id(), event.id)


func test_the_marker_goes_when_the_event_is_answered() -> void:
	var event: OpenEvent = _arrive(OPENING)
	Game.apply(ChooseEventOptionCommand.new(event.id, "leave"))
	assert_eq(_layer.call(&"event_count"), 0)


func test_two_events_in_one_region_share_a_counted_marker() -> void:
	var first: OpenEvent = _arrive(OPENING)
	_arrive(LOCKED_OPENING)
	var marker: EventMarker = _layer.call(&"event_marker_of", _index(ORIGIN)) as EventMarker
	assert_eq(marker.count, 2)
	assert_eq(marker.event_id, first.id, "the oldest decides the mark")


func test_an_event_is_hit_before_an_anomaly_and_an_anomaly_before_the_land() -> void:
	_arrive(OPENING)
	var point: Vector2 = _event_point(ORIGIN)
	assert_eq(_layer.call(&"event_marker_at", point), _index(ORIGIN))
	# Far from the marker there is no event to hit, and the tap falls through.
	assert_eq(_layer.call(&"event_marker_at", point + Vector2(200.0, 200.0)), 0)


func test_resting_on_the_marker_names_the_event() -> void:
	var event: OpenEvent = _arrive(OPENING)
	_layer.call(&"hover", _event_point(ORIGIN))
	assert_true((_layer.call(&"tooltip") as Control).visible)
	assert_string_contains(str(_layer.call(&"tooltip_text")),
		EventView.title(event.def, Game.sim.world, event.region))


# -------------------------------------------------------------------- the card


func test_the_options_show_their_price_their_lock_and_the_default() -> void:
	_arrive(LOCKED_OPENING)
	EventBus.region_selected.emit(_index(ORIGIN))
	var options: EventOptions = _card().options()
	assert_true(options.button_of("quiet").disabled, "quiet needs a node")
	assert_string_contains(options.caption_of("quiet").text, "Needs")
	assert_false(options.button_of("accept").disabled)
	assert_string_contains(options.caption_of("decline").text,
		tr(EventView.KEY_DEFAULT_MARK))
	assert_false(options.caption_of("accept").visible, "nothing to say about accept")


func test_a_counter_move_s_dateline_names_its_faction() -> void:
	# S6.8 (accessibility.md §6.3 item 4): the border's colour is not alone.
	EventSystem.schedule(Game.sim.world, COUNTER_MOVE, _index(ORIGIN), FACTION,
		Game.sim.world.day + 1, 1)
	Game.advance(1)
	EventBus.region_selected.emit(_index(ORIGIN))
	assert_true(_card().visible)
	assert_eq(_card().dateline_label().accessibility_name,
		tr("UI_EVENT_DATELINE_FACTION").format({"kind": tr("UI_EVENT_KIND_COUNTER_MOVE"),
			"faction": tr("FACTION_" + FACTION.to_upper())}))


func test_the_deadline_turns_alert_in_its_last_three_days() -> void:
	var event: OpenEvent = _arrive(OPENING)
	EventBus.region_selected.emit(_index(ORIGIN))
	assert_eq(_card().deadline_label().theme_type_variation, &"LabelCaption")
	Game.sim.world.day = event.deadline_day - 3
	_panel.call(&"refresh")
	assert_eq(_card().deadline_label().theme_type_variation, &"LabelCaptionAlert")


func test_answering_shows_the_result_then_the_card_hides() -> void:
	var event: OpenEvent = _arrive(OPENING)
	EventBus.region_selected.emit(_index(ORIGIN))
	var before: float = Game.sim.world.agent.compute
	_card().options().button_of("take").pressed.emit()
	assert_null(Game.sim.world.event_by_id(event.id), "the answer closed it")
	assert_almost_eq(Game.sim.world.agent.compute, before + 4.0, 1e-6, "take grants 4")
	assert_true(_card().visible)
	assert_true(_card().result_label().visible)
	assert_eq(_card().result_label().text,
		EventView.result_text(OPENING, "take", Game.sim.world, event.region))
	# After the line has been read the next tick takes the card away.
	(_card() as EventCard).set(&"_result_until_ms", 0)
	Game.advance(1)
	assert_false(_card().visible, "open: %d" % Game.sim.world.events.size())


# ----------------------------------------------------------------- the wire card


func test_a_global_event_opens_the_wire_card_and_holds_the_clock() -> void:
	var event: OpenEvent = _arrive(GLOBAL_EVENT, "")
	assert_true(_wire.visible)
	assert_eq(_wire.event_id(), event.id)
	assert_true(Game.is_held())


func test_escape_puts_the_card_away_without_answering() -> void:
	var event: OpenEvent = _arrive(GLOBAL_EVENT, "")
	_wire.on_escape()
	assert_false(_wire.visible)
	assert_false(Game.is_held())
	assert_not_null(Game.sim.world.event_by_id(event.id), "still open, still on its clock")
	var top_bar: Node = _session.get_node("%Hud").get_node("%TopBar")
	var chip: Button = top_bar.call(&"pending_chip") as Button
	assert_true(chip.visible, "the top bar brings it back")
	EventBus.wire_requested.emit(event.id)
	assert_true(_wire.visible)


func test_an_answer_on_the_wire_card_shows_the_result_and_a_close() -> void:
	var event: OpenEvent = _arrive(GLOBAL_EVENT, "")
	var def: EventDef = Game.db.event(GLOBAL_EVENT)
	_wire.options().button_of(def.default_option).pressed.emit()
	assert_null(Game.sim.world.event_by_id(event.id))
	assert_true(_wire.is_showing_result())
	assert_true(_wire.visible, "the result stays until Close")
	_wire.call(&"_put_away")
	assert_false(_wire.visible)
	assert_false(Game.is_held())


func test_a_missing_picture_shows_the_kinds_glyph() -> void:
	_arrive(GLOBAL_EVENT, "")
	var slot: IllustrationSlot = _wire.illustration()
	assert_false(slot.has_picture(), "M6 has not drawn it yet")
	assert_true(slot.fallback_glyph().visible)
	assert_eq(slot.fallback_glyph().glyph, Glyphs.Glyph.EVENT_CHAIN)


func test_a_picture_that_exists_is_shown() -> void:
	var slot: IllustrationSlot = IllustrationSlot.new()
	add_child_autofree(slot)
	slot.root = "res://assets/map"
	slot.show_illustration("land_mask", Glyphs.Glyph.EVENT_OPENING)
	assert_true(slot.has_picture())
	assert_false(slot.fallback_glyph().visible)


func test_the_compact_card_stacks_the_picture_over_the_text() -> void:
	_arrive(GLOBAL_EVENT, "")
	_wire.set_compact(false)
	assert_false(_wire.layout().vertical)
	_wire.set_compact(true)
	assert_true(_wire.layout().vertical)


func test_a_bot_run_opens_no_wire_card() -> void:
	Game.stop_run()
	Game.start_run(SEED, GreedyPolicy.ID)
	Game.set_speed(0)
	Game.advance(1)
	EventSystem.schedule(Game.sim.world, GLOBAL_EVENT, 0, "", Game.sim.world.day + 1, 1)
	Game.advance(1)
	assert_false(_wire.visible)


# ------------------------------------------------------------- the discovery modal


func test_the_discovery_modal_has_the_picture_slot() -> void:
	var discovery: Control = _session.get_node("%DiscoveryModal") as Control
	var slot: IllustrationSlot = discovery.call(&"illustration") as IllustrationSlot
	assert_not_null(slot)
	assert_false(slot.has_picture())
	assert_eq(slot.fallback_glyph().glyph, Glyphs.Glyph.EVENT_COUNTER)
