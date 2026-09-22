extends SlidePanel
## Everything the player can know about one region (spec ui-foundation.md §5.6).
##
## It opens on a selection, re-reads its region after every tick, and closes on
## the close button, `Escape`, or a tap on the ocean — all three of which arrive
## as `region_selected(0)`.
##
## The order of the sections is the spec's and is not a matter of taste: a region
## is read top-down as name, state, presence, people, profile, connections, and
## whatever is happening in it right now. M4 adds to the `Extra` box at the end
## and moves nothing.
##
## Scene-specific, so no `class_name` — it extends `SlidePanel`, which is the
## component.

const KEY_CONTINENT: String = "CONTINENT_"
const KEY_REGION: String = "REGION_"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"

const KEY_STATE_UNTOUCHED: String = "UI_REGION_STATE_UNTOUCHED"
const KEY_STATE_SEEDED: String = "UI_REGION_STATE_SEEDED"
const KEY_STATE_CONTROLLED: String = "UI_REGION_STATE_CONTROLLED"
const KEY_STATE_DARK: String = "UI_REGION_STATE_DARK"
const KEY_AIR_GAPPED: String = "UI_REGION_AIR_GAPPED"

const KEY_PENETRATION: String = "UI_TERM_PENETRATION"
const KEY_CONTROL: String = "UI_TERM_CONTROL"
const KEY_ALIVE: String = "UI_REGION_POPULATION_ALIVE"
const KEY_DEATHS: String = "UI_REGION_POPULATION_DEATHS"
const KEY_ATTRIBUTES: String = "UI_REGION_ATTRIBUTES"
const KEY_LINKS: String = "UI_REGION_LINKS"
const KEY_LINK_ROW: String = "UI_REGION_LINK_ROW"
const KEY_LINK_ROW_CLOSED: String = "UI_REGION_LINK_ROW_CLOSED"
const KEY_ANOMALY: String = "UI_REGION_ANOMALY"
const KEY_ANOMALY_EXPIRES: String = "UI_REGION_ANOMALY_EXPIRES"
const KEY_COLLECT: String = "UI_REGION_COLLECT"

## §5.6's profile, in the order it lists: attribute name → its label key.
const ATTRIBUTE_KEYS: Dictionary[String, String] = {
	"compute": "UI_ATTR_COMPUTE",
	"connectivity": "UI_ATTR_CONNECTIVITY",
	"research": "UI_ATTR_RESEARCH",
	"regulation": "UI_ATTR_REGULATION",
	"wealth": "UI_ATTR_WEALTH",
	"industry": "UI_ATTR_INDUSTRY",
	"manufacturing": "UI_ATTR_MANUFACTURING",
	"isolation": "UI_ATTR_ISOLATION",
}
## Link kind → its label key, in the order the rows appear (§5.6).
const LINK_KEYS: Dictionary[String, String] = {
	LinkDef.KIND_LAND: "UI_LINK_LAND",
	LinkDef.KIND_SEA: "UI_LINK_SEA",
	LinkDef.KIND_AIR: "UI_LINK_AIR",
	LinkDef.KIND_NETWORK: "UI_LINK_NETWORK",
}

const PLACEHOLDER_DAY: String = "day"
const PLACEHOLDER_KIND: String = "kind"
const PLACEHOLDER_COUNT: String = "count"
const PLACEHOLDER_CLOSED: String = "closed"
const PLACEHOLDER_VALUE: String = "value"

const VARIATION_CAPTION: StringName = &"LabelCaption"
const VARIATION_HEADING: StringName = &"LabelHeading"
const VARIATION_ROW: StringName = &"Row"
const VARIATION_STAT_PENETRATION: StringName = &"StatBarPenetration"

const STAT_BAR_SCENE: String = "res://ui/components/stat_bar.tscn"

@onready var _name_label: Label = %RegionName
@onready var _close_button: IconButton = %CloseButton
@onready var _continent: Label = %Continent
@onready var _chips: HFlowContainer = %Chips
@onready var _presence: VBoxContainer = %Presence
@onready var _alive_value: ValueLabel = %AliveValue
@onready var _deaths_row: HBoxContainer = %DeathsRow
@onready var _deaths_value: ValueLabel = %DeathsValue
@onready var _profile_title: Label = %ProfileTitle
@onready var _grid: GridContainer = %Profile
@onready var _links_title: Label = %LinksTitle
@onready var _links: VBoxContainer = %Links
@onready var _anomaly_box: PanelContainer = %AnomalyBox
@onready var _anomaly_label: Label = %AnomalyLabel
@onready var _anomaly_expires: Label = %AnomalyExpires
@onready var _collect_button: ConsoleButton = %CollectButton

## The region on show; 0 when the panel is closed.
var _index: int = 0

var _penetration_bar: StatBar = null
var _control_bar: StatBar = null
var _pips: Dictionary[String, AttributePips] = {}
var _link_rows: Dictionary[String, Label] = {}


func _ready() -> void:
	super()
	_build_presence()
	_build_profile()
	_build_links()
	_close_button.pressed.connect(_on_close_pressed)
	_collect_button.pressed.connect(_on_collect_pressed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.run_started.connect(_on_run_started)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		refresh()


## The two section headings. Everything else on the panel wraps a number or a
## content id and is rewritten by `refresh`.
func _refresh_strings() -> void:
	_profile_title.text = tr(KEY_ATTRIBUTES)
	_links_title.text = tr(KEY_LINKS)


## §5.6: `Escape` closes the panel, the same way the close button does. It is a
## shortcut and not unhandled input: by the time an event is unhandled the focus
## system has had it, and a focused button swallows the key.
func _shortcut_input(event: InputEvent) -> void:
	if not is_open:
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	_close()
	get_viewport().set_input_as_handled()


## The region the panel is showing, 0 for none.
func region_index() -> int:
	return _index


## Re-reads the region. Called after every tick, so a region that goes dark or
## grows an anomaly says so without being re-selected.
func refresh() -> void:
	if _index <= 0:
		return
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null or Game.db == null or _index >= world.regions.size():
		return
	var region: Region = world.regions[_index]
	_name_label.text = tr(KEY_REGION + region.def.id.to_upper())
	_continent.text = tr(KEY_CONTINENT + region.def.continent.to_upper())
	_refresh_chips(region)
	_refresh_presence(region)
	_refresh_population(region)
	_refresh_profile(region)
	_refresh_links(world)
	_refresh_anomaly(world)


# ------------------------------------------------------------- the sections


## Exactly one state chip, plus the air-gap badge where it applies (§5.6).
func _refresh_chips(region: Region) -> void:
	for child: Node in _chips.get_children():
		child.queue_free()
	var chip: Chip = Chip.new()
	if region.dark:
		chip.kind = Chip.Kind.ALERT
		chip.set_label(KEY_STATE_DARK)
	elif region.control >= Game.db.balance.control_complete:
		chip.kind = Chip.Kind.ACCENT
		chip.set_label(KEY_STATE_CONTROLLED)
	elif region.seeded_day >= 0:
		chip.kind = Chip.Kind.ACCENT
		chip.set_label(KEY_STATE_SEEDED, {PLACEHOLDER_DAY: region.seeded_day})
	else:
		chip.set_label(KEY_STATE_UNTOUCHED)
	_chips.add_child(chip)
	if region.air_gapped:
		var gapped: Chip = Chip.new()
		gapped.kind = Chip.Kind.ALERT
		gapped.set_label(KEY_AIR_GAPPED)
		_chips.add_child(gapped)


func _refresh_presence(region: Region) -> void:
	# Nothing is there yet, so there is nothing to measure (§5.6).
	_presence.visible = region.seeded_day >= 0 or region.dark
	_penetration_bar.set_value(region.penetration)
	_control_bar.set_value(region.control)


func _refresh_population(region: Region) -> void:
	_alive_value.set_number(region.alive, Format.Kind.COMPACT)
	_deaths_value.set_number(region.deaths, Format.Kind.COMPACT)
	_deaths_row.visible = region.deaths >= 1.0


func _refresh_profile(region: Region) -> void:
	for attribute: String in ATTRIBUTE_KEYS:
		_pips[attribute].tier = region.def.attr(attribute)


## One row per link kind the region has, counting the closed ones separately.
func _refresh_links(world: World) -> void:
	var counts: Dictionary[String, int] = {}
	var closed: Dictionary[String, int] = {}
	for kind: String in LINK_KEYS:
		counts[kind] = 0
		closed[kind] = 0
	for link: Link in world.links:
		if link.def.a != _index and link.def.b != _index:
			continue
		counts[link.def.kind] += 1
		if not link.open:
			closed[link.def.kind] += 1
	for kind: String in LINK_KEYS:
		var row: Label = _link_rows[kind]
		row.visible = counts[kind] > 0
		if not row.visible:
			continue
		var args: Dictionary = {
			PLACEHOLDER_KIND: tr(LINK_KEYS[kind]),
			PLACEHOLDER_COUNT: counts[kind],
			PLACEHOLDER_CLOSED: closed[kind],
		}
		var key: String = KEY_LINK_ROW_CLOSED if closed[kind] > 0 else KEY_LINK_ROW
		row.text = tr(key).format(args)


func _refresh_anomaly(world: World) -> void:
	var anomaly: Anomaly = world.anomaly_in_region(_index)
	_anomaly_box.visible = anomaly != null
	if anomaly == null:
		return
	_anomaly_label.text = tr(KEY_ANOMALY).format({
		PLACEHOLDER_VALUE: Format.number(anomaly.value, Format.Kind.COMPUTE)})
	_anomaly_expires.text = tr(KEY_ANOMALY_EXPIRES).format({
		PLACEHOLDER_DAY: anomaly.expires_day})


# ------------------------------------------------------------ what is built


## The two bars of §5.6's presence section. Both take the penetration variation:
## in a region, presence and hold are the same kind of quantity.
func _build_presence() -> void:
	var scene: PackedScene = load(STAT_BAR_SCENE) as PackedScene
	_penetration_bar = _make_bar(scene, KEY_PENETRATION)
	_control_bar = _make_bar(scene, KEY_CONTROL)


func _make_bar(scene: PackedScene, key: String) -> StatBar:
	var bar: StatBar = scene.instantiate() as StatBar
	bar.theme_type_variation = VARIATION_STAT_PENETRATION
	bar.label_key = key
	_presence.add_child(bar)
	return bar


func _build_profile() -> void:
	for attribute: String in ATTRIBUTE_KEYS:
		var label: CapsLabel = CapsLabel.new()
		label.label_key = ATTRIBUTE_KEYS[attribute]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pips: AttributePips = AttributePips.new()
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.add_child(label)
		_grid.add_child(pips)
		_pips[attribute] = pips


func _build_links() -> void:
	for kind: String in LINK_KEYS:
		var row: Label = Label.new()
		row.visible = false
		_links.add_child(row)
		_link_rows[kind] = row


# ---------------------------------------------------------------- the wiring


func _show_region(index: int) -> void:
	_index = index
	refresh()
	open()


func _close() -> void:
	# One door: the map clears its outline on the same signal (§7.4).
	if _index != 0:
		EventBus.region_selected.emit(0)
		return
	close()


func _on_region_selected(index: int) -> void:
	if index <= 0:
		_index = 0
		close()
		return
	_show_region(index)


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()


## A new run re-indexes nothing, but the region on show belongs to the old world.
func _on_run_started(_seed_value: int) -> void:
	_index = 0
	close()


func _on_close_pressed() -> void:
	_close()


func _on_collect_pressed() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null:
		return
	var anomaly: Anomaly = world.anomaly_in_region(_index)
	if anomaly == null:
		return
	Game.apply(CollectAnomalyCommand.new(anomaly.id))
