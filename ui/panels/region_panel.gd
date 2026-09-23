extends SlidePanel
## Everything the player can know about one region (spec ui-foundation.md §5.6).
##
## It opens on a selection, re-reads its region after every tick, and closes on
## the close button, `Escape`, or a tap on the ocean — all three of which arrive
## as `region_selected(0)`. `Escape` itself belongs to the session (§5.2): a
## focused button swallows a key before any panel sees it, so every key of the
## run is taken in one place, ahead of the GUI.
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
## A chip cannot wrap, so what being dark means is a caption under the chip row
## rather than a longer badge (§5.6, G2).
const KEY_STATE_DARK_DETAIL: String = "UI_REGION_STATE_DARK_DETAIL"
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

## m3-screens §8.1: the dormancy row, which exists once the branch is owned.
const KEY_DORMANCY: String = "UI_REGION_DORMANCY"
const KEY_DORMANCY_TIP: String = "UI_REGION_DORMANCY_TIP"
const KEY_DORMANT_ON: String = "UI_REGION_DORMANT_ON"
const KEY_DORMANT_OFF: String = "UI_REGION_DORMANT_OFF"
const KEY_STATE_DORMANT: String = "UI_REGION_STATE_DORMANT"
const KEY_DORMANT_DETAIL: String = "UI_REGION_DORMANT_DETAIL"
const PREFIX_FAIL: String = "CMD_FAIL_"

## m3-screens §7.2, generalised by `loop-mechanics.md` §16.1 item 3a: while the
## map is being asked **where**, every region answers one question — may it be
## the site? The origin is one of the three kinds.
const KEY_ORIGIN_CHOOSE: String = "UI_ORIGIN_CHOOSE"
const KEY_ORIGIN_AIRGAP: String = "UI_ORIGIN_INELIGIBLE_AIRGAP"
const KEY_ORIGIN_COMPUTE: String = "UI_ORIGIN_INELIGIBLE_COMPUTE"
const KEY_SITE_PLACE: String = "UI_SITE_PLACE"
const KEY_SITE_USE: String = "UI_SITE_USE"
const PREFIX_ELIGIBLE: String = "UI_ELIGIBLE_"
const PREFIX_ATTR: String = "UI_ATTR_"
const PREFIX_STATUS: String = "STATUS_"
const SUFFIX_NAME: String = "_NAME"
const ATTRIBUTE_COMPUTE: String = "compute"

## §16.5 item 9: what the agent has standing in this region.
const KEY_ASSETS: String = "UI_REGION_ASSETS"
const KEY_ASSET_ROW: String = "UI_REGION_ASSET_ROW"
## §16.5: the glyph in an asset row.
const ASSET_GLYPH_SIZE: float = 16.0

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
@onready var _dark_detail: Label = %DarkDetail
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
@onready var _dormancy_row: Control = %DormancyRow
@onready var _dormancy_label: CapsLabel = %DormancyLabel
@onready var _dormancy_button: ConsoleButton = %DormancyButton
@onready var _dormancy_failure: Label = %DormancyFailure
@onready var _dormant_detail: Label = %DormantDetail
@onready var _origin_row: Control = %OriginRow
@onready var _origin_button: ConsoleButton = %OriginButton
@onready var _origin_note: Label = %OriginNote
@onready var _assets_block: Control = %AssetsBlock
@onready var _assets_title: Label = %AssetsTitle
@onready var _assets: VBoxContainer = %Assets

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
	_dormancy_button.pressed.connect(_on_dormancy_pressed)
	_origin_button.pressed.connect(_on_origin_pressed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.run_started.connect(_on_run_started)
	EventBus.site_select_changed.connect(_on_site_select_changed)
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
	_dark_detail.text = tr(KEY_STATE_DARK_DETAIL)
	_assets_title.text = tr(KEY_ASSETS)


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
	_refresh_site(region, world)
	_refresh_dormancy(region)
	_refresh_presence(region)
	_refresh_population(region)
	_refresh_profile(region)
	_refresh_links(world)
	_refresh_anomaly(world)
	_refresh_assets(region)


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
	if region.dormant:
		var held: Chip = Chip.new()
		held.kind = Chip.Kind.ACCENT
		held.set_label(KEY_STATE_DORMANT)
		_chips.add_child(held)
	_dark_detail.visible = region.dark
	_dormant_detail.visible = region.dormant
	_dormant_detail.text = tr(KEY_DORMANT_DETAIL)


## §16.1 item 3a: while a site is being chosen, this region either offers the
## one button that answers or says why it cannot. Eligibility is the request's
## own rule, asked through the request — the panel decides nothing.
func _refresh_site(region: Region, world: World) -> void:
	var request: SiteRequest = Game.site_request
	var choosing: bool = request != null
	_origin_row.visible = choosing
	_dormancy_row.visible = _dormancy_row.visible and not choosing
	if not choosing:
		return
	var reason: String = request.reason_for(_index)
	_origin_button.visible = reason.is_empty()
	_origin_button.label_key = _site_button_key(request)
	_origin_note.visible = not reason.is_empty()
	_origin_note.text = _site_reason_text(request, region, reason)


static func _site_button_key(request: SiteRequest) -> String:
	match request.kind:
		SiteRequest.KIND_DEPLOY:
			return KEY_SITE_PLACE
		SiteRequest.KIND_ABILITY:
			return KEY_SITE_USE
	return KEY_ORIGIN_CHOOSE


## The origin's rule is a command's, so it has command reasons; every other
## request answers with an `Eligibility` code and its arguments (§17.2).
func _site_reason_text(request: SiteRequest, region: Region, reason: String) -> String:
	if request.kind == SiteRequest.KIND_ORIGIN:
		return tr(KEY_ORIGIN_AIRGAP if region.air_gapped else KEY_ORIGIN_COMPUTE)
	if not Eligibility.REASONS.has(reason):
		return tr(PREFIX_FAIL + reason.to_upper())
	return tr(PREFIX_ELIGIBLE + reason.to_upper()).format(_eligible_args(request))


## The failing key's own arguments, with every id turned into a name.
func _eligible_args(request: SiteRequest) -> Dictionary:
	if request.rule == null:
		return {}
	var raw: Dictionary = request.rule.detail(Game.sim.world, _index)
	var args: Dictionary = raw.duplicate()
	if raw.has("attr"):
		args["attr"] = tr(PREFIX_ATTR + str(raw["attr"]).to_upper())
	if raw.has("kind"):
		args["kind"] = TechText.asset_name(str(raw["kind"]), int(raw.get("count", 1)))
	if raw.has("status"):
		args["status"] = tr(PREFIX_STATUS + str(raw["status"]).to_upper() + SUFFIX_NAME)
	if raw.has("value"):
		args["value"] = Format.percent(float(raw["value"]))
	if raw.has("continent"):
		args["continent"] = tr(KEY_CONTINENT + str(raw["continent"]).to_upper())
	return args


## §16.5 item 9: one row per kind held, in `AssetDef.KINDS` order.
func _refresh_assets(region: Region) -> void:
	for child: Node in _assets.get_children():
		_assets.remove_child(child)
		child.queue_free()
	_assets_block.visible = region.has_assets()
	if not _assets_block.visible:
		return
	for kind: String in AssetDef.KINDS:
		var count: int = region.asset_count(kind)
		if count <= 0:
			continue
		_assets.add_child(_asset_row(kind, count))


func _asset_row(kind: String, count: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = VARIATION_ROW
	var icon: GlyphIcon = GlyphIcon.new()
	icon.glyph = Glyphs.asset_glyph(Game.db.assets[kind].glyph)
	icon.box_size = ASSET_GLYPH_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var label: Label = Label.new()
	label.text = tr(KEY_ASSET_ROW).format({
		PLACEHOLDER_COUNT: count,
		PLACEHOLDER_KIND: TechText.asset_name(kind, count),
	})
	row.add_child(label)
	return row


func _refresh_presence(region: Region) -> void:
	# Nothing is there yet, so there is nothing to measure (§5.6). While the
	# origin is being chosen the row above answers instead (§7.2).
	_presence.visible = (region.seeded_day >= 0 or region.dark) \
		and Game.sim.world.agent.origin != 0
	_penetration_bar.set_value(region.penetration)
	_control_bar.set_value(region.control)
	# §8.1: a held region's numbers are frozen, and say so by being muted.
	var muted: StringName = &"ValueLabelMuted" if region.dormant else &"ValueLabel"
	for bar: StatBar in [_penetration_bar, _control_bar]:
		(bar.get_node("%Value") as ValueLabel).variation_base = muted


## §8.1: the row appears with the `dormancy` flag and says which state the region
## is in — never which action the button would take.
func _refresh_dormancy(region: Region) -> void:
	var world: World = Game.sim.world
	_dormancy_row.visible = world.modifiers.has_flag(ModifierDef.FLAG_DORMANCY)
	if not _dormancy_row.visible:
		_dormancy_failure.visible = false
		return
	_dormancy_label.label_key = KEY_DORMANCY
	_dormancy_button.label_key = KEY_DORMANT_ON if region.dormant else KEY_DORMANT_OFF
	_dormancy_button.tooltip_key = KEY_DORMANCY_TIP
	_dormancy_button.disabled = region.dark or region.penetration <= 0.0


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
	var was_open: bool = is_open
	open()
	_reveal(index, was_open)


## §5.6: the panel covers the part of the map it is talking about, so the map is
## asked to bring the region out from behind it (G2: a tap on the USA put the
## USA under the panel). The panel is laid out by then, so the rectangle it
## leaves free is the one the camera gets.
##
## Nothing happens without a map — the panel is tested on its own — and nothing
## happens while the panel was already open on another region: the player is
## reading, and the map should not slide out from under the pointer.
func _reveal(index: int, was_open: bool) -> void:
	if was_open or Game.db == null or index <= 0 or index >= Game.db.regions.size():
		return
	var camera: MapCamera = MapCamera.find_in_tree(self)
	if camera == null:
		return
	camera.reveal(Vector2(Game.db.regions[index].anchor), uncovered_rect())


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


## The one action on this panel that can be refused, so the reason goes under the
## row rather than nowhere (§8.1).
func _on_dormancy_pressed() -> void:
	if Game.sim == null or _index <= 0:
		return
	var region: Region = Game.sim.world.regions[_index]
	var result: CommandResult = Game.apply(
		SetDormancyCommand.new(region.def.id, not region.dormant))
	_dormancy_failure.visible = not result.ok
	if not result.ok:
		_dormancy_failure.text = tr(PREFIX_FAIL + result.reason.to_upper())
		return
	refresh()


## The one button of §16.1 item 3a. Whatever the request builds is what is sent,
## and a refusal is reported where the button was.
func _on_origin_pressed() -> void:
	if _index <= 0 or Game.site_request == null:
		return
	var result: CommandResult = Game.site_confirm(Game.sim.world.regions[_index].def.id)
	_origin_note.visible = not result.ok
	if not result.ok:
		_origin_note.text = tr(PREFIX_FAIL + result.reason.to_upper())
	refresh()


func _on_site_select_changed(_active: bool) -> void:
	refresh()


func _on_collect_pressed() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null:
		return
	var anomaly: Anomaly = world.anomaly_in_region(_index)
	if anomaly == null:
		return
	Game.apply(CollectAnomalyCommand.new(anomaly.id))
