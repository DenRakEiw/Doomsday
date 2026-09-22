extends PanelContainer
## What the selected node is and does (spec m3-screens.md §3.6).
##
## Everything here is generated from the definition: the effect lines come from
## `TechText`, the prerequisite rows from the graph, the state chip from the
## state the board computed. Nothing about a node is written twice.
##
## Scene-specific, so no `class_name`.

## A prerequisite row was pressed: the modal switches tab and selects it.
signal jump_requested(node_id: String)
signal buy_requested(node_id: String)
## The sheet's own CLOSE button, which only the compact layout shows (§3.6).
signal close_requested

const KEY_TIER: String = "UI_TREE_TIER"
const KEY_BUY: String = "UI_TREE_BUY"
const KEY_OWNED: String = "UI_TREE_OWNED"
const KEY_OWNED_DAY: String = "UI_TREE_OWNED_DAY"
const KEY_LOCKED_HINT: String = "UI_TREE_LOCKED_HINT"
const KEY_IN_TAB: String = "UI_TREE_IN_TAB"
const KEY_WATCHED_NONE: String = "UI_TREE_WATCHED_NONE"
const KEY_REQUIRES_ANY_HINT: String = "UI_TREE_REQUIRES_ANY_HINT"
const KEY_EMPTY_HINT: String = "UI_TREE_EMPTY_HINT"
const KEY_EFFECTS: String = "UI_TREE_EFFECTS"
const KEY_REQUIRES: String = "UI_TREE_REQUIRES"
const KEY_REQUIRES_ANY: String = "UI_TREE_REQUIRES_ANY"
const KEY_EFFECT: String = "TECH_%s_EFFECT"
const KEY_FLAVOUR: String = "TECH_%s_FLAVOUR"
const KEY_FAIL_GENERIC: String = "CMD_FAIL_GENERIC"
const PREFIX_FAIL: String = "CMD_FAIL_"
const PREFIX_FACTION: String = "FACTION_"
const KEY_MISSING: String = "missing"

## The tab names, by tree id — the chip in the caption row and the `in {tab}`
## suffix of a prerequisite from elsewhere.
const TAB_KEY: Dictionary[String, String] = {
	"infiltration": "UI_TREE_TAB_INFILTRATION",
	"capabilities": "UI_TREE_TAB_CAPABILITIES",
	"evasion": "UI_TREE_TAB_EVASION",
}
## The state chip, in the order of `TechNode.State`.
const STATE_KEY: Array[String] = ["UI_TREE_STATE_LOCKED", "UI_TREE_STATE_AVAILABLE",
	"UI_TREE_STATE_AFFORDABLE", "UI_TREE_STATE_OWNED"]
const STATE_IS_ACCENT: Array[bool] = [false, false, true, true]

@onready var _empty_hint: Label = %EmptyHint
@onready var _effects_title: Label = %EffectsTitle
@onready var _requires_title: Label = %RequiresTitle
@onready var _requires_any_title: Label = %RequiresAnyTitle
@onready var _requires_any_hint: Label = %RequiresAnyHint
@onready var _body: Control = %Body
@onready var _title: Label = %Title
@onready var _tier: Label = %Tier
@onready var _tree_chip: Chip = %TreeChip
@onready var _state_chip: Chip = %StateChip
@onready var _effect: Label = %Effect
@onready var _flavour: Label = %Flavour
@onready var _effects: VBoxContainer = %Effects
@onready var _requires_block: Control = %RequiresBlock
@onready var _requires: VBoxContainer = %Requires
@onready var _requires_any_block: Control = %RequiresAnyBlock
@onready var _requires_any: VBoxContainer = %RequiresAny
@onready var _watched: HFlowContainer = %Watched
@onready var _watched_none: Label = %WatchedNone
@onready var _buy: ConsoleButton = %Buy
@onready var _owned_chip: Chip = %OwnedChip
@onready var _locked_hint: Label = %LockedHint
@onready var _failure: Label = %Failure
@onready var _close_button: IconButton = %DetailClose

var _node_id: String = ""


func _ready() -> void:
	_buy.pressed.connect(_on_buy_pressed)
	_close_button.pressed.connect(close_requested.emit)
	set_compact(false)
	_refresh_strings()
	clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


## The headings, which say the same thing whatever is selected.
func _refresh_strings() -> void:
	_empty_hint.text = tr(KEY_EMPTY_HINT)
	_effects_title.text = tr(KEY_EFFECTS)
	_requires_title.text = tr(KEY_REQUIRES)
	_requires_any_title.text = tr(KEY_REQUIRES_ANY)
	_requires_any_hint.text = tr(KEY_REQUIRES_ANY_HINT)


## In the compact layout the pane is a sheet, and a sheet needs a way out of its
## own (§3.6).
func set_compact(compact: bool) -> void:
	_close_button.visible = compact


## Nothing is selected: one line, and the rest of the pane is out of the way.
func clear() -> void:
	_node_id = ""
	_empty_hint.visible = true
	_body.visible = false
	_failure.visible = false


## Shows `definition` in the state the board computed for it.
func show_node(definition: TechNodeDef, sim: Simulation, state: TechNode.State,
		cost: float, purchase_day: int) -> void:
	_node_id = definition.id
	_empty_hint.visible = false
	_body.visible = true
	_failure.visible = false
	_fill_head(definition, state)
	_fill_effects(definition, sim.db)
	_fill_prerequisites(definition, sim)
	_fill_watchers(definition)
	_fill_buy(definition, sim, state, cost, purchase_day)


## The reason the last purchase was refused (§3.3). It goes away with the next
## selection or the next success.
func show_failure(reason: String) -> void:
	_failure.visible = true
	_failure.text = _failure_text(reason)


## The node the pane is showing, or "" while nothing is selected.
func shown_id() -> String:
	return _node_id


func _fill_head(definition: TechNodeDef, state: TechNode.State) -> void:
	_title.text = TechText.node_name(definition.id)
	_tier.text = tr(KEY_TIER).format({"tier": definition.tier})
	_tree_chip.set_label(TAB_KEY[definition.tree])
	_state_chip.set_label(STATE_KEY[state])
	_state_chip.kind = Chip.Kind.ACCENT if STATE_IS_ACCENT[state] else Chip.Kind.DEFAULT
	_effect.text = tr(KEY_EFFECT % definition.id.to_upper())
	_flavour.text = tr(KEY_FLAVOUR % definition.id.to_upper())


## One caption per modifier, flag and one-shot, in the order the data lists them.
func _fill_effects(definition: TechNodeDef, db: ContentDB) -> void:
	_clear(_effects)
	for modifier: ModifierDef in definition.modifiers:
		_add_caption(_effects, TechText.modifier_line(modifier, db))
	for flag: String in definition.flags:
		_add_caption(_effects, TechText.flag_line(flag))
	for effect: PurchaseEffectDef in definition.on_purchase:
		_add_caption(_effects, TechText.effect_line(effect))


func _fill_prerequisites(definition: TechNodeDef, sim: Simulation) -> void:
	_fill_rows(_requires_block, _requires, definition.requires, definition.tree, sim)
	_fill_rows(_requires_any_block, _requires_any, definition.requires_any, definition.tree,
		sim)


func _fill_rows(block: Control, into: VBoxContainer, ids: Array[String], tree: String,
		sim: Simulation) -> void:
	_clear(into)
	block.visible = not ids.is_empty()
	for node_id: String in ids:
		into.add_child(_prerequisite_row(node_id, tree, sim))


## A flat button, because pressing it goes somewhere (§3.6 item 6).
func _prerequisite_row(node_id: String, tree: String, sim: Simulation) -> Control:
	var definition: TechNodeDef = sim.db.tech(node_id)
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"Row"
	var button: ConsoleButton = ConsoleButton.new()
	button.list_row = true
	button.text = TechText.node_name(node_id)
	button.accessibility_name = button.text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_row_pressed.bind(node_id))
	row.add_child(button)
	var state: Chip = Chip.new()
	var node_state: TechNode.State = TechNode.state_for(definition, sim)
	state.set_label(STATE_KEY[node_state])
	state.kind = Chip.Kind.ACCENT if STATE_IS_ACCENT[node_state] else Chip.Kind.DEFAULT
	row.add_child(state)
	if definition.tree != tree:
		var elsewhere: Label = Label.new()
		elsewhere.theme_type_variation = &"LabelCaption"
		elsewhere.text = tr(KEY_IN_TAB).format({"tab": tr(TAB_KEY[definition.tree])})
		row.add_child(elsewhere)
	return row


func _fill_watchers(definition: TechNodeDef) -> void:
	_clear(_watched)
	_watched_none.visible = definition.watched_by.is_empty()
	_watched_none.text = tr(KEY_WATCHED_NONE)
	for faction: String in definition.watched_by:
		var chip: Chip = Chip.new()
		chip.set_label(PREFIX_FACTION + faction.to_upper())
		_watched.add_child(chip)


func _fill_buy(definition: TechNodeDef, sim: Simulation, state: TechNode.State, cost: float,
		purchase_day: int) -> void:
	var owned: bool = state == TechNode.State.OWNED
	_buy.visible = not owned
	_owned_chip.visible = owned
	_locked_hint.visible = not owned and state == TechNode.State.LOCKED
	_locked_hint.text = tr(KEY_LOCKED_HINT)
	if owned:
		_owned_chip.set_label(KEY_OWNED if purchase_day < 0 else KEY_OWNED_DAY,
			{"day": Format.number(float(purchase_day), Format.Kind.DAYS)})
		return
	_buy.text = Format.caps(tr(KEY_BUY).format(
		{"cost": Format.number(cost, Format.Kind.COMPUTE)}))
	_buy.disabled = not sim.can_apply(PurchaseNodeCommand.new(definition.id)).is_empty()


## The reason, with the shortfall spelled out where there is one (§3.3).
func _failure_text(reason: String) -> String:
	var key: String = PREFIX_FAIL + reason.to_upper()
	if reason == Command.FAIL_INSUFFICIENT_COMPUTE:
		return tr(key).format({KEY_MISSING: _shortfall()})
	var translated: String = tr(key)
	if translated == key:
		return tr(KEY_FAIL_GENERIC).format({"reason": reason})
	return translated


func _shortfall() -> String:
	if Game.sim == null or _node_id.is_empty():
		return ""
	var missing: float = maxf(0.0, Game.sim.node_cost(_node_id) - Game.sim.world.agent.compute)
	return Format.number(missing, Format.Kind.COMPUTE)


## A caption is already `TEXT_2`, which is what §3.6 asks an inert line to be —
## the line itself says that nothing reads it yet.
func _add_caption(into: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	into.add_child(label)


static func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_row_pressed(node_id: String) -> void:
	jump_requested.emit(node_id)


func _on_buy_pressed() -> void:
	if not _node_id.is_empty():
		buy_requested.emit(_node_id)
