extends SlidePanel
## "How much trouble am I in" (spec m3-screens.md §4).
##
## Everything on it is read from the simulation on every tick — the two pure
## queries of §10.5 answer with exactly what the next tick will do, so the panel
## can never disagree with the run.
##
## Scene-specific, so no `class_name`.

const FACTION_TRACK: PackedScene = preload("res://ui/components/faction_track.tscn")

const KEY_TITLE: String = "UI_CONTAINMENT_TITLE"
const KEY_UNDISCOVERED: String = "UI_CONTAINMENT_UNDISCOVERED"
const KEY_DISCOVERED: String = "UI_CONTAINMENT_DISCOVERED"
const KEY_RISK: String = "UI_CONTAINMENT_RISK"
const KEY_TRACKS: String = "UI_CONTAINMENT_TRACKS"
const KEY_NOT_YET: String = "UI_CONTAINMENT_NOT_YET"
const KEY_DRIVERS: String = "UI_CONTAINMENT_DRIVERS"
const KEY_THRESHOLDS: String = "UI_CONTAINMENT_THRESHOLDS_HINT"
const KEY_CAUSE_SCRUTINY: String = "UI_DISCOVERY_CAUSE_SCRUTINY"
const KEY_CAUSE_DEATHS: String = "UI_DISCOVERY_CAUSE_DEATHS"
const PREFIX_FACTION: String = "FACTION_"
const PLACEHOLDER_PERCENT: String = "percent"
const PLACEHOLDER_DAY: String = "day"

## The three terms of the discovery risk, in the order §4.1 lists them.
const RISK_KEYS: Array[String] = ["UI_CONTAINMENT_RISK_TIME", "UI_CONTAINMENT_RISK_FOOTPRINT",
	"UI_CONTAINMENT_RISK_BREADTH"]
const RISK_FIELDS: Array[String] = [ContainmentSystem.RISK_TIME, ContainmentSystem.RISK_FOOTPRINT,
	ContainmentSystem.RISK_BREADTH]
## The six rows of "what feeds it", their field, and whether the value is a
## factor (`×1.3`) or a share.
const DRIVER_KEYS: Array[String] = ["UI_CONTAINMENT_DRIVER_FOOTPRINT",
	"UI_CONTAINMENT_DRIVER_HARM", "UI_CONTAINMENT_DRIVER_SHARE",
	"UI_CONTAINMENT_DRIVER_CAPACITY", "UI_CONTAINMENT_DRIVER_BRAKES",
	"UI_CONTAINMENT_DRIVER_DAILY"]
const DRIVER_FIELDS: Array[String] = [ContainmentSystem.DRIVER_FOOTPRINT,
	ContainmentSystem.DRIVER_HARM, ContainmentSystem.DRIVER_SHARE,
	ContainmentSystem.DRIVER_CAPACITY, ContainmentSystem.DRIVER_BRAKES,
	ContainmentSystem.DRIVER_GAIN]
enum DriverForm { FACTOR, PERCENT, FINE }
const DRIVER_FORMS: Array[DriverForm] = [DriverForm.FACTOR, DriverForm.FACTOR,
	DriverForm.FACTOR, DriverForm.PERCENT, DriverForm.FACTOR, DriverForm.FINE]
## The brakes read as a good thing when they are below 1 (§4.1).
const DRIVER_BRAKES_ROW: int = 4

@onready var _close_button: IconButton = %ContainmentClose
@onready var _title: Label = %ContainmentTitle
@onready var _status_chip: Chip = %StatusChip
@onready var _risk: Label = %RiskLine
@onready var _risk_rows: VBoxContainer = %RiskRows
@onready var _cause: Label = %Cause
@onready var _tracks_title: Label = %TracksTitle
@onready var _tracks: VBoxContainer = %Tracks
@onready var _not_yet: Label = %NotYet
@onready var _drivers_block: Control = %DriversBlock
@onready var _drivers_title: Label = %DriversTitle
@onready var _drivers: VBoxContainer = %Drivers
@onready var _thresholds: Label = %ThresholdsHint

## Faction id → its track, built once per run.
var _track_nodes: Dictionary[String, FactionTrack] = {}
## The value labels of the driver rows, in the order of `DRIVER_KEYS`.
var _driver_values: Array[ValueLabel] = []
var _risk_values: Array[Label] = []


func _ready() -> void:
	super()
	_build_risk_rows()
	_build_driver_rows()
	_close_button.pressed.connect(close)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.run_started.connect(_on_run_started)
	EventBus.sim_event.connect(_on_sim_event)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		refresh()


## Re-reads the run. Called on every tick and whenever the panel opens.
func refresh() -> void:
	if Game.sim == null:
		return
	var world: World = Game.sim.world
	_build_tracks(world)
	_apply_status(world)
	_apply_tracks(world)
	_apply_drivers(world)


func open() -> void:
	refresh()
	super()


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_tracks_title.text = tr(KEY_TRACKS)
	_drivers_title.text = tr(KEY_DRIVERS)
	_not_yet.text = tr(KEY_NOT_YET)
	_thresholds.text = tr(KEY_THRESHOLDS)
	for i: int in RISK_KEYS.size():
		_risk_values[i].text = tr(RISK_KEYS[i])
	for i: int in DRIVER_KEYS.size():
		var row: HBoxContainer = _drivers.get_child(i) as HBoxContainer
		(row.get_child(0) as Label).text = tr(DRIVER_KEYS[i])


# ------------------------------------------------------------------- content


## Undiscovered: the risk and where it comes from. Discovered: the day and why.
func _apply_status(world: World) -> void:
	var discovered: bool = world.discovered
	_status_chip.set_label(KEY_DISCOVERED if discovered else KEY_UNDISCOVERED,
		{PLACEHOLDER_DAY: Format.number(float(world.discovery_day), Format.Kind.DAYS)})
	_status_chip.kind = Chip.Kind.ALERT if discovered else Chip.Kind.ACCENT
	_risk.visible = not discovered
	_risk_rows.visible = not discovered
	_cause.visible = discovered
	_not_yet.visible = not discovered
	if discovered:
		_cause.text = tr(_cause_key(world))
		return
	var risk: Dictionary = Game.sim.discovery_risk()
	_risk.text = tr(KEY_RISK).format({PLACEHOLDER_PERCENT:
		Format.percent_fine(float(risk[ContainmentSystem.RISK_TOTAL]))})
	for i: int in RISK_KEYS.size():
		_risk_values[i].text = tr(RISK_KEYS[i]).format({PLACEHOLDER_PERCENT:
			Format.percent_fine(float(risk[RISK_FIELDS[i]]))})


## Why they found you. The simulation keeps no cause and the event is long gone
## by the time the panel is opened again, so it is derived from the rule that
## produced it: deaths on the certain scale are the one cause nobody rolls for
## (core.md §7.5).
static func _cause_key(world: World) -> String:
	if Game.db != null and world.deaths_total() / Game.db.population_total 			>= Game.db.balance.discovery_deaths_certain_share:
		return KEY_CAUSE_DEATHS
	return KEY_CAUSE_SCRUTINY


func _build_tracks(world: World) -> void:
	if _track_nodes.size() == world.factions.size():
		return
	for child: Node in _tracks.get_children():
		_tracks.remove_child(child)
		child.queue_free()
	_track_nodes.clear()
	for faction: Faction in world.factions:
		var track: FactionTrack = FACTION_TRACK.instantiate()
		_tracks.add_child(track)
		_track_nodes[faction.id] = track


func _apply_tracks(world: World) -> void:
	var thresholds: Array[float] = Game.db.balance.containment_thresholds
	for faction: Faction in world.factions:
		var track: FactionTrack = _track_nodes[faction.id]
		track.bind(PREFIX_FACTION + faction.id.to_upper(), faction.containment,
			Game.containment_rates.get(faction.id, 0.0), thresholds)


## The six rows of §4.1 item 4, hidden until there is something to feed.
func _apply_drivers(world: World) -> void:
	_drivers_block.visible = world.discovered
	if not world.discovered:
		return
	var breakdown: Dictionary = Game.sim.containment_breakdown()
	for i: int in DRIVER_KEYS.size():
		var value: float = float(breakdown[DRIVER_FIELDS[i]])
		var label: ValueLabel = _driver_values[i]
		match DRIVER_FORMS[i]:
			DriverForm.FACTOR:
				label.text = Format.factor(value)
			DriverForm.PERCENT:
				label.text = Format.percent(value)
			_:
				label.text = Format.percent_fine(value)
		if i == DRIVER_BRAKES_ROW:
			label.variation_base = &"ValueLabelUp" if value < 1.0 else &"ValueLabel"


# --------------------------------------------------------------------- rows


func _build_risk_rows() -> void:
	for key: String in RISK_KEYS:
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_risk_rows.add_child(label)
		_risk_values.append(label)


## A label on the left, a number on the right — the shape every readout on this
## panel has.
func _build_driver_rows() -> void:
	for key: String in DRIVER_KEYS:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"Row"
		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"LabelCaption"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value: ValueLabel = ValueLabel.new()
		row.add_child(value)
		_drivers.add_child(row)
		_driver_values.append(value)


func _on_tick_advanced(_day: int) -> void:
	if is_open:
		refresh()


func _on_run_started(_seed_value: int) -> void:
	close()
	for child: Node in _tracks.get_children():
		_tracks.remove_child(child)
		child.queue_free()
	_track_nodes.clear()


## A rollback is the one moment containment falls, and the track shows it (§4.2).
func _on_sim_event(event: SimEvent) -> void:
	if event.type != SimEvent.CONTAINMENT_ROLLED_BACK:
		return
	var faction: String = str(event.data["faction"])
	if _track_nodes.has(faction):
		_track_nodes[faction].flash_rollback(float(event.data["from"]),
			float(event.data["to"]))
