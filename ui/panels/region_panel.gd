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

## §16.5 item 10: what is running here, and who put it there.
const KEY_STATUS: String = "UI_REGION_STATUS"
const KEY_STATUS_DAYS: String = "UI_REGION_STATUS_DAYS"
const KEY_STATUS_STANDING: String = "UI_REGION_STATUS_STANDING"
const KEY_STATUS_YOURS: String = "UI_REGION_STATUS_YOURS"
const KEY_STATUS_FACTION: String = "UI_REGION_STATUS_FACTION"
const KEY_STATUS_WORLD: String = "UI_REGION_STATUS_WORLD"
const KEY_STATUS_OPTION: String = "UI_REGION_STATUS_OPTION"
## §16.5 item 13: the abilities that can be used here.
const KEY_ACTIONS: String = "UI_REGION_ACTIONS"
const KEY_ACTION_COST: String = "UI_REGION_ACTION_COST"
const KEY_ACTION_FREE: String = "UI_REGION_ACTION_FREE"
const KEY_ACTION_COOLDOWN: String = "UI_REGION_ACTION_COOLDOWN"
const KEY_ACTION_LEVEL: String = "UI_REGION_ACTION_LEVEL"
const PREFIX_FACTION: String = "FACTION_"
const SUFFIX_DETAIL: String = "_DETAIL"
const SUFFIX_CODE: String = "_CODE"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_COST: String = "cost"
const PLACEHOLDER_LEVEL: String = "level"
const PLACEHOLDER_STATUS: String = "status"
const PLACEHOLDER_FACTION: String = "faction"
const PLACEHOLDER_OPTION: String = "option"

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
## opposition.md §9.3: the Society row.
const KEY_SOCIETY: String = "UI_REGION_SOCIETY"
const KEY_SOCIETY_CUTS: String = "UI_REGION_SOCIETY_CUTS"
const KEY_SOCIETY_TIP: String = "UI_REGION_SOCIETY_TIP"
const PREFIX_SOCIETY_STAGE: String = "SOCIETY_STAGE_"
const PLACEHOLDER_CAPACITY: String = "capacity"
const PLACEHOLDER_YIELD: String = "yield"
## From this stage on the chip wears the accent; never `ALERT` — it is a state.
const SOCIETY_ACCENT_STAGE: int = 2

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
@onready var _task_force_row: Control = %TaskForceRow
@onready var _task_force_chip: Chip = %TaskForceChip
@onready var _task_force_line: Label = %TaskForceLine
@onready var _task_force_marked: Label = %TaskForceMarked
@onready var _status_block: Control = %StatusBlock
@onready var _status_title: Label = %StatusTitle
@onready var _statuses: VBoxContainer = %Statuses
@onready var _event_card: EventCard = %EventCard
@onready var _actions_block: Control = %ActionsBlock
@onready var _actions_title: Label = %ActionsTitle
@onready var _actions: VBoxContainer = %Actions

## The region on show; 0 when the panel is closed.
var _index: int = 0

var _penetration_bar: StatBar = null
var _control_bar: StatBar = null
var _pips: Dictionary[String, AttributePips] = {}
var _link_rows: Dictionary[String, Label] = {}
## §9.3's row, built in code after the Status block: heading, stage chip, cuts.
var _society_block: VBoxContainer = null
var _society_title: Label = null
var _society_chip: Chip = null
var _society_cuts: Label = null


func _ready() -> void:
	super()
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(get_node("Panel/Scroll") as ScrollContainer)
	# first-run.md §3.3: the introduction points at the one button of site select.
	_origin_button.add_to_group(CoachRing.group(CoachRing.TARGET_ORIGIN_BUTTON))
	_build_presence()
	_build_profile()
	_build_links()
	_build_society()
	_close_button.pressed.connect(_on_close_pressed)
	# first-run.md §6.7: the page for this screen, before the close button.
	HelpButton.before(_close_button, HelpPages.CONTEXT_REGION)
	# §6.3: the ability hint's ring goes round the actions.
	_actions_block.add_to_group(CoachRing.group(CoachRing.TARGET_ACTIONS))
	_collect_button.pressed.connect(_on_collect_pressed)
	_dormancy_button.pressed.connect(_on_dormancy_pressed)
	_origin_button.pressed.connect(_on_origin_pressed)
	EventBus.region_selected.connect(_on_region_selected)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.run_started.connect(_on_run_started)
	EventBus.site_select_changed.connect(_on_site_select_changed)
	EventBus.event_card_requested.connect(_on_event_card_requested)
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
	_status_title.text = tr(KEY_STATUS)
	_actions_title.text = tr(KEY_ACTIONS)
	_society_title.text = tr(KEY_SOCIETY)
	_society_block.tooltip_text = tr(KEY_SOCIETY_TIP)


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
	# accessibility.md §3.3: the panel is named by its region.
	accessibility_name = _name_label.text
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
	_refresh_task_force(world)
	_refresh_statuses(world)
	_refresh_society(region)
	_event_card.show_region(_index)
	_refresh_actions()


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
	_origin_note.text = request.reason_text(_index)


static func _site_button_key(request: SiteRequest) -> String:
	match request.kind:
		SiteRequest.KIND_DEPLOY:
			return KEY_SITE_PLACE
		SiteRequest.KIND_ABILITY:
			return KEY_SITE_USE
	return KEY_ORIGIN_CHOOSE




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


## §16.5 item 10: one row per running status, in application order, each saying
## what it is, how long it has left and who put it there.
## §9.3: hidden at 0; the stage chip and what the stage costs the humans here.
func _refresh_society(region: Region) -> void:
	_society_block.visible = region.society > 0.0 and not region.dark
	if not _society_block.visible:
		return
	var balance: BalanceDef = Game.db.balance
	var stage: int = SocietalFunctionSystem.stage(region.society, balance)
	_society_chip.set_label(PREFIX_SOCIETY_STAGE + str(stage))
	_society_chip.kind = Chip.Kind.ACCENT if stage >= SOCIETY_ACCENT_STAGE \
		else Chip.Kind.DEFAULT
	_society_cuts.text = tr(KEY_SOCIETY_CUTS).format({
		PLACEHOLDER_CAPACITY: Format.change(SocietalFunctionSystem.capacity_mul(region.society,
			balance)),
		PLACEHOLDER_YIELD: Format.change(SocietalFunctionSystem.yield_mul(region.society, balance)),
	})


func _build_society() -> void:
	_society_block = VBoxContainer.new()
	_society_block.name = "SocietyBlock"
	_society_block.theme_type_variation = &"StackTight"
	_society_block.visible = false
	_society_block.mouse_filter = Control.MOUSE_FILTER_PASS
	_society_title = Label.new()
	_society_title.theme_type_variation = VARIATION_HEADING
	_society_block.add_child(_society_title)
	var row: HFlowContainer = HFlowContainer.new()
	row.theme_type_variation = &"FlowSnug"
	_society_chip = Chip.new()
	row.add_child(_society_chip)
	_society_block.add_child(row)
	# S6.P3: the cuts read as percentages now (`+0 %` where `×1` stood) and no
	# longer fit beside the chip on a 400 px phone — a line of their own, wrapped.
	_society_cuts = Label.new()
	_society_cuts.theme_type_variation = VARIATION_CAPTION
	_society_cuts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_society_block.add_child(_society_cuts)
	var body: Node = _status_block.get_parent()
	body.add_child(_society_block)
	body.move_child(_society_block, _status_block.get_index() + 1)


## The row of §9.3, for the tests.
func society_block() -> Control:
	return _society_block


## `taskforce-endings.md` §9: the team stands here, sets up here, or — when the
## player may see it — is on its way here.
func _refresh_task_force(world: World) -> void:
	# §14.4: the mark shows whatever the team is doing — the player needs it
	# before choosing dormancy.
	var marked: String = TaskForceText.marked_line(world, Game.db, _index)
	_task_force_marked.visible = not marked.is_empty()
	_task_force_marked.text = marked
	var line: String = TaskForceText.region_line(world, Game.db, _index)
	_task_force_row.visible = not line.is_empty()
	if line.is_empty():
		return
	_task_force_chip.kind = Chip.Kind.TASK_FORCE
	_task_force_chip.set_label(TaskForceText.KEY_CODE)
	_task_force_chip.tooltip_text = tr(TaskForceText.KEY_TITLE)
	_task_force_line.text = line


func _refresh_statuses(world: World) -> void:
	for child: Node in _statuses.get_children():
		_statuses.remove_child(child)
		child.queue_free()
	var running: Array[Status] = world.statuses_in_region(_index)
	_status_block.visible = not running.is_empty()
	for status: Status in running:
		_statuses.add_child(_status_row(status, world))


func _status_row(status: Status, world: World) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = &"StackTight"
	# plain-language.md §5.2 C3: the detail, what the status does, its days.
	box.tooltip_text = StatusText.tooltip(Game.db, status, world.day)

	var head: HBoxContainer = HBoxContainer.new()
	head.theme_type_variation = VARIATION_ROW
	# icons.md §7: the status's icon before its code, in the chip's colour.
	var icon: IconRect = IconRect.new()
	icon.box_size = float(UiTokens.ICON_ROW)
	icon.color_token = UiTokens.status_token(status.source)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.show_icon(Icons.KIND_STATUS, status.id)
	head.add_child(icon)
	var chip: Chip = Chip.new()
	chip.set_status_source(status.source)
	chip.set_label(PREFIX_STATUS + status.id.to_upper() + SUFFIX_CODE)
	head.add_child(chip)
	var name_label: Label = Label.new()
	name_label.text = tr(PREFIX_STATUS + status.id.to_upper() + SUFFIX_NAME)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var days: Label = Label.new()
	days.theme_type_variation = VARIATION_CAPTION
	days.text = tr(KEY_STATUS_STANDING) if status.is_standing() \
		else tr(KEY_STATUS_DAYS).format({PLACEHOLDER_DAYS: status.days_left(world.day)})
	head.add_child(days)
	box.add_child(head)

	var source: Label = Label.new()
	source.theme_type_variation = VARIATION_CAPTION
	source.text = _status_source_text(status)
	box.add_child(source)
	return box


## Whose status it is, and — when an event's option applied it — which option.
## A world status with no faction behind it is the world's own (D4.3, §11.3).
func _status_source_text(status: Status) -> String:
	var line: String = ""
	var faction: String = status.faction()
	if not faction.is_empty():
		line = tr(KEY_STATUS_FACTION).format(
			{PLACEHOLDER_FACTION: tr(PREFIX_FACTION + faction.to_upper())})
	elif _is_world_status(status):
		line = tr(KEY_STATUS_WORLD)
	else:
		line = tr(KEY_STATUS_YOURS)
	# The status keeps the answered option's id but not the event it answered;
	# a faction's move is the one counter-move with this status, so the option's
	# text can be found without a save field (S4.P — the line printed the id).
	var def: EventDef = _counter_move_of(status, faction)
	if status.option.is_empty() or def == null or def.option(status.option) == null:
		return line
	var option_key: String = "EVENT_%s_OPT_%s" % [def.id.to_upper(), status.option.to_upper()]
	return line + tr(KEY_STATUS_OPTION).format({PLACEHOLDER_OPTION: tr(option_key)})


func _counter_move_of(status: Status, faction: String) -> EventDef:
	if faction.is_empty():
		return null
	for def: EventDef in Game.db.events:
		if def.kind == EventDef.KIND_COUNTER_MOVE and def.status == status.id \
				and def.faction == faction:
			return def
	return null


func _is_world_status(status: Status) -> bool:
	var definition: StatusDef = Game.db.status(status.id)
	return definition != null and definition.origin == StatusDef.ORIGIN_WORLD


## §16.3.2: a tap on an event marker opens the panel on that region and brings
## its card into view. The card is laid out on the next frame, so the scroll
## waits for it. A card taller than the view starts at its heading (S7.IP: the
## scroll to its end hid the title, seen on the itch capture).
func scroll_to_event() -> void:
	if not _event_card.visible:
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var scroll: ScrollContainer = get_node("Panel/Scroll") as ScrollContainer
	if scroll == null:
		return
	if _event_card.size.y <= scroll.size.y:
		scroll.ensure_control_visible(_event_card)
		return
	var top: float = _event_card.get_global_rect().position.y 		- scroll.get_global_rect().position.y + float(scroll.scroll_vertical)
	scroll.scroll_vertical = int(top)


func _on_event_card_requested(region_index: int) -> void:
	if region_index == _index:
		scroll_to_event()


## The event card, for the tests.
func event_card() -> EventCard:
	return _event_card


## §16.5 item 13: one button per unlocked region ability, in `abilities.json`
## order, enabled exactly when the command would be accepted.
func _refresh_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var shown: int = 0
	for ability: AbilityDef in Game.db.abilities:
		if not ability.targets_region() or Game.sim.ability_level(ability.id) == 0:
			continue
		# §4: Misdirect is offered only while there is a team to mislead — a verb
		# with nothing to act on anywhere is not a choice, it is noise.
		if not Game.sim.ability_blocker(ability.id).is_empty():
			continue
		_actions.add_child(_action_row(ability))
		shown += 1
	_actions_block.visible = shown > 0


func _action_row(ability: AbilityDef) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = &"StackTight"
	var region_id: String = Game.sim.world.regions[_index].def.id
	var reason: String = Game.sim.can_apply(UseAbilityCommand.new(ability.id, region_id))

	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = VARIATION_ROW
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = AbilityDef.name_key(ability.id)
	button.tooltip_key = AbilityDef.detail_key(ability.id)
	button.disabled = not reason.is_empty()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# icons.md §7: the ability's icon, tinted by the button's state colours.
	button.icon = Icons.texture(Icons.KIND_ABILITY, ability.id, UiTokens.ICON_ROW)
	button.pressed.connect(_on_action_pressed.bind(ability.id))
	row.add_child(button)
	var chip: Chip = Chip.new()
	if ability.cost <= 0.0:
		chip.set_label(KEY_ACTION_FREE)
	else:
		chip.set_label(KEY_ACTION_COST, {PLACEHOLDER_COST:
			Format.number(ability.cost, Format.Kind.COMPUTE)})
	row.add_child(chip)
	box.add_child(row)

	var caption: Label = Label.new()
	caption.theme_type_variation = VARIATION_CAPTION
	caption.text = _action_caption(ability, reason)
	caption.visible = not caption.text.is_empty()
	box.add_child(caption)
	return box


## The cooldown first — it is the one reason that passes on its own — then why
## the region does not take it, then the level when there is more than one.
func _action_caption(ability: AbilityDef, reason: String) -> String:
	if reason == Command.FAIL_ABILITY_COOLDOWN:
		var days: int = Game.sim.ability_ready_day(ability.id) - Game.sim.world.day
		return tr(KEY_ACTION_COOLDOWN).format({PLACEHOLDER_DAYS: maxi(0, days)})
	if not reason.is_empty():
		if Eligibility.REASONS.has(reason):
			return tr(PREFIX_ELIGIBLE + reason.to_upper()).format(
				_ability_args(ability))
		return tr(PREFIX_FAIL + reason.to_upper())
	if ability.max_level() > 1:
		return tr(KEY_ACTION_LEVEL).format(
			{PLACEHOLDER_LEVEL: Game.sim.ability_level(ability.id)})
	return ""


## The failing eligibility key's own arguments, with every id turned into a name.
func _ability_args(ability: AbilityDef) -> Dictionary:
	if ability.eligible == null:
		return {}
	var raw: Dictionary = ability.eligible.detail(Game.sim.world, _index)
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


## Sends the ability at this region. A refusal shows under its own button, as
## everywhere else on this panel.
func _on_action_pressed(ability_id: String) -> void:
	if Game.sim == null or _index <= 0:
		return
	Game.apply(UseAbilityCommand.new(ability_id, Game.sim.world.regions[_index].def.id))
	refresh()


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


## accessibility.md §4.4: the site button while a site is being chosen, else the
## first enabled action, else close.
func primary_focus() -> Control:
	if _origin_button.is_visible_in_tree() and not _origin_button.disabled:
		return _origin_button
	var roots: Array[Control] = [self]
	for control: Control in FocusRing.collect(roots):
		if control != _close_button and not control is HelpButton:
			return control
	return _close_button


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
