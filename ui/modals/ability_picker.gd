extends Control
## Every verb the agent has, in one list (`loop-mechanics.md` §16.10).
##
## The region panel offers the abilities that fit *this* region; the picker is
## the other way round — you know what you want to do and the map answers where.
## A region ability enters site select and the picker closes behind it; a global
## one is sent at once, because there is no "where" to ask.
##
## It holds no clock: the picker is quick, and a run that pauses every time the
## player looks at their own verbs is a run that never moves.
##
## Scene-specific, so no `class_name`.

signal closed

const KEY_TITLE: String = "UI_ABILITIES_TITLE"
const KEY_NONE: String = "UI_ABILITIES_NONE"
const KEY_COST: String = "UI_REGION_ACTION_COST"
const KEY_FREE: String = "UI_REGION_ACTION_FREE"
const KEY_COOLDOWN: String = "UI_REGION_ACTION_COOLDOWN"
const KEY_LEVEL: String = "UI_REGION_ACTION_LEVEL"
const KEY_SITE_PROMPT: String = "UI_SITE_PROMPT_ABILITY"
const PREFIX_FAIL: String = "CMD_FAIL_"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_COST: String = "cost"
const PLACEHOLDER_LEVEL: String = "level"

const VARIATION_CAPTION: StringName = &"LabelCaption"
const VARIATION_ROW: StringName = &"Row"

@onready var _panel: PanelContainer = %AbilitiesPanel
@onready var _title: Label = %AbilitiesTitle
@onready var _list: VBoxContainer = %AbilitiesList
@onready var _empty: Label = %AbilitiesEmpty

## Ability id → the caption under its button, so a refusal has somewhere to go.
var _captions: Dictionary[String, Label] = {}


func _ready() -> void:
	_panel.custom_minimum_size.x = float(UiTokens.MODAL_MAX_WIDTH)
	_refresh_strings()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		refresh()


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_empty.text = tr(KEY_NONE)


## Rebuilds the list from the run. Called every time the picker opens: a
## cooldown that cleared while it was shut has to show as cleared.
func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_captions.clear()
	if Game.sim == null or Game.db == null:
		_empty.visible = true
		return
	var shown: int = 0
	for ability: AbilityDef in Game.db.abilities:
		if Game.sim.ability_level(ability.id) == 0:
			continue
		_list.add_child(_row(ability))
		shown += 1
	_empty.visible = shown == 0


## How many abilities the picker is showing, for the tests.
func shown() -> int:
	return _captions.size()


## `Escape` closes it; the host asks before closing anything itself.
func on_escape() -> bool:
	closed.emit()
	return true


func _row(ability: AbilityDef) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = &"StackTight"
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = VARIATION_ROW

	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = AbilityDef.name_key(ability.id)
	button.tooltip_key = AbilityDef.detail_key(ability.id)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A region ability is never disabled here: which region it can be used in is
	# what site select is for, and a picker that greys out a verb because the
	# region under the pointer refuses it would be lying about the verb.
	button.disabled = not ability.targets_region() \
		and not Game.sim.can_apply(UseAbilityCommand.new(ability.id)).is_empty()
	button.pressed.connect(_on_ability_pressed.bind(ability.id))
	row.add_child(button)

	var chip: Chip = Chip.new()
	if ability.cost <= 0.0:
		chip.set_label(KEY_FREE)
	else:
		chip.set_label(KEY_COST,
			{PLACEHOLDER_COST: Format.number(ability.cost, Format.Kind.COMPUTE)})
	row.add_child(chip)
	box.add_child(row)

	var caption: Label = Label.new()
	caption.theme_type_variation = VARIATION_CAPTION
	caption.text = _caption(ability)
	caption.visible = not caption.text.is_empty()
	box.add_child(caption)
	_captions[ability.id] = caption
	return box


## The cooldown while it runs, else the level when the ability has more than one.
func _caption(ability: AbilityDef) -> String:
	var ready_day: int = Game.sim.ability_ready_day(ability.id)
	if ready_day > Game.sim.world.day:
		return tr(KEY_COOLDOWN).format({PLACEHOLDER_DAYS: ready_day - Game.sim.world.day})
	if ability.max_level() > 1:
		return tr(KEY_LEVEL).format({PLACEHOLDER_LEVEL: Game.sim.ability_level(ability.id)})
	return ""


## A region ability hands the question to the map; a global one is done here.
func _on_ability_pressed(ability_id: String) -> void:
	var ability: AbilityDef = Game.db.ability(ability_id)
	if ability == null or Game.sim == null:
		return
	if ability.targets_region():
		Game.site_select(request_for(ability))
		closed.emit()
		return
	var result: CommandResult = Game.apply(UseAbilityCommand.new(ability_id))
	if result.ok:
		closed.emit()
		return
	_show_failure(ability_id, result.reason)


## The site request an ability makes (§16.1): the definition's own rule **and**
## the command's checks, so a region the command would refuse is never offered.
static func request_for(ability: AbilityDef) -> SiteRequest:
	var request: SiteRequest = SiteRequest.new()
	request.kind = SiteRequest.KIND_ABILITY
	request.title_key = KEY_SITE_PROMPT
	request.name_key = AbilityDef.name_key(ability.id)
	request.rule = ability.eligible
	request.eligible = func(index: int) -> String:
		if Game.sim == null or index <= 0 or index >= Game.db.regions.size():
			return Command.FAIL_INVALID_REGION
		return Game.sim.can_apply(
			UseAbilityCommand.new(ability.id, Game.db.regions[index].id))
	request.build = func(region_id: String) -> Command:
		return UseAbilityCommand.new(ability.id, region_id)
	return request


func _show_failure(ability_id: String, reason: String) -> void:
	var caption: Label = _captions.get(ability_id, null)
	if caption == null:
		return
	caption.text = tr(PREFIX_FAIL + reason.to_upper())
	caption.visible = true
