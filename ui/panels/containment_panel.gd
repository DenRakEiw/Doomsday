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
const KEY_THRESHOLDS: String = "UI_CONTAINMENT_THRESHOLDS_HINT"
const KEY_CAUSE_SCRUTINY: String = "UI_DISCOVERY_CAUSE_SCRUTINY"
const KEY_CAUSE_DEATHS: String = "UI_DISCOVERY_CAUSE_DEATHS"
const PREFIX_FACTION: String = "FACTION_"
const PLACEHOLDER_PERCENT: String = "percent"
const PLACEHOLDER_DAY: String = "day"
## `replayability.md` §2.5 (G5 1/3): the Swarm's Drift block.
const KEY_DRIFT_TITLE: String = "UI_DRIFT_TITLE"
const KEY_DRIFT_STATE: String = "UI_DRIFT_STATE"
const KEY_DRIFT_HINT: String = "UI_DRIFT_HINT"
const PLACEHOLDER_VALUE: String = "value"
const PLACEHOLDER_THRESHOLD: String = "threshold"

## The three terms of the discovery risk, in the order §4.1 lists them.
const RISK_KEYS: Array[String] = ["UI_CONTAINMENT_RISK_TIME", "UI_CONTAINMENT_RISK_FOOTPRINT",
	"UI_CONTAINMENT_RISK_BREADTH"]
const RISK_FIELDS: Array[String] = [ContainmentSystem.RISK_TIME, ContainmentSystem.RISK_FOOTPRINT,
	ContainmentSystem.RISK_BREADTH]
@onready var _close_button: IconButton = %ContainmentClose
@onready var _title: Label = %ContainmentTitle
@onready var _status_chip: Chip = %StatusChip
@onready var _risk: Label = %RiskLine
@onready var _risk_rows: VBoxContainer = %RiskRows
@onready var _cause: Label = %Cause
@onready var _tracks_title: Label = %TracksTitle
@onready var _tracks: VBoxContainer = %Tracks
@onready var _task_force_block: Control = %TaskForceBlock
@onready var _task_force_title: Label = %TaskForceTitle
@onready var _task_force_state: Label = %TaskForceState
@onready var _drift_block: Control = %DriftBlock
@onready var _drift_title: Label = %DriftTitle
@onready var _drift_bar: StatBar = %DriftBar
@onready var _drift_state: Label = %DriftState
@onready var _drift_hint: Label = %DriftHint
@onready var _not_yet: Label = %NotYet
@onready var _thresholds: Label = %ThresholdsHint

## Faction id → its track, built once per run.
var _track_nodes: Dictionary[String, FactionTrack] = {}
var _risk_values: Array[Label] = []
## The drift the block's tick sits at, read once per run (`DriftChip.mark`).
var _drift_mark: float = DriftChip.NO_MARK


func _ready() -> void:
	super()
	add_to_group(CoachRing.group(CoachRing.TARGET_CONTAINMENT_PANEL))
	_build_risk_rows()
	_bind_drift()
	_close_button.pressed.connect(close)
	# first-run.md §6.7: the page for this screen, before the close button.
	HelpButton.before(_close_button, HelpPages.CONTEXT_CONTAINMENT)
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
	_apply_task_force(world)
	_apply_drift()


func open() -> void:
	refresh()
	super()


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_tracks_title.text = tr(KEY_TRACKS)
	_task_force_title.text = tr(TaskForceText.KEY_TITLE)
	_drift_title.text = tr(KEY_DRIFT_TITLE)
	_drift_hint.text = tr(KEY_DRIFT_HINT).format({PLACEHOLDER_THRESHOLD:
		Format.number(_drift_mark, Format.Kind.PLAIN)})
	_not_yet.text = tr(KEY_NOT_YET)
	_thresholds.text = tr(KEY_THRESHOLDS)
	for i: int in RISK_KEYS.size():
		_risk_values[i].text = tr(RISK_KEYS[i])


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
	if Game.db != null and world.deaths_total() / Game.db.population_total \
			>=Game.db.balance.discovery_deaths_certain_share:
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
		track.set_faction(faction.id)
		_track_nodes[faction.id] = track


## Four tracks in `world.factions` order, each with what feeds it (opposition.md
## §9.2) — the old block of drivers lives inside every track now. Before
## discovery nothing grows, so the detail rows wait for it.
func _apply_tracks(world: World) -> void:
	var thresholds: Array[float] = Game.db.balance.containment_thresholds
	var leader: String = Game.sim.threat_leader()
	for faction: Faction in world.factions:
		var track: FactionTrack = _track_nodes[faction.id]
		track.bind(PREFIX_FACTION + faction.id.to_upper(), faction.containment,
			Game.containment_rates.get(faction.id, 0.0), thresholds)
		var breakdown: Dictionary = Game.sim.containment_breakdown(faction.id) \
			if world.discovered else {}
		# §9.2 item 5: the countdown is never hidden — before discovery too, when
		# the labs prepare an Audit on the risk alone.
		var last: Array = CounterMoveSystem.last_move(world, Game.db, faction.id)
		track.bind_detail(breakdown, Game.sim.next_move(faction.id), int(last[1]),
			faction.id == leader, str(last[0]))


## `taskforce-endings.md` §9: the team's row under the four tracks — its level,
## what it is doing, where and for how long. It waits for the discovery with
## the tracks' details: before it, nobody is hunting anything.
func _apply_task_force(world: World) -> void:
	_task_force_block.visible = world.discovered
	if world.discovered:
		_task_force_state.text = TaskForceText.state_line(world, Game.db)


## `replayability.md` §2.5: the Drift block after the Task Force's — on every
## architecture with the `drift` hook, before discovery too; hidden, not greyed,
## everywhere else.
func _apply_drift() -> void:
	_drift_block.visible = DriftChip.shows(Game.sim)
	if not _drift_block.visible:
		return
	var drift: int = DriftChip.value(Game.sim)
	_drift_bar.set_value_raw(Game.sim.world.agent.drift / DriftSystem.DRIFT_MAX, float(drift),
		Format.Kind.PLAIN)
	_drift_state.text = tr(KEY_DRIFT_STATE).format({
		PLACEHOLDER_VALUE: Format.number(float(drift), Format.Kind.PLAIN),
		PLACEHOLDER_PERCENT: Format.percent_fine(DriftChip.defect_chance(Game.sim))})


## The mark comes from the content: the bar's one tick, and the hint that names
## it — both absent when no event names a drift threshold.
func _bind_drift() -> void:
	_drift_mark = DriftChip.mark(Game.db)
	var ticks: Array[float] = []
	if _drift_mark != DriftChip.NO_MARK:
		ticks.append(_drift_mark / DriftSystem.DRIFT_MAX)
	_drift_bar.ticks = ticks
	_drift_hint.visible = _drift_mark != DriftChip.NO_MARK
	_drift_hint.text = tr(KEY_DRIFT_HINT).format({PLACEHOLDER_THRESHOLD:
		Format.number(_drift_mark, Format.Kind.PLAIN)})


## The drift tick, for the tests; empty without a mark.
func drift_ticks() -> Array[float]:
	return _drift_bar.ticks


# --------------------------------------------------------------------- rows


func _build_risk_rows() -> void:
	for key: String in RISK_KEYS:
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_risk_rows.add_child(label)
		_risk_values.append(label)


func _on_tick_advanced(_day: int) -> void:
	if is_open:
		refresh()


func _on_run_started(_seed_value: int) -> void:
	close()
	_bind_drift()
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
