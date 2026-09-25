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

## `loop-mechanics.md` §16.6: the rows tree v3 adds, after *Prerequisites* and
## before *Watched by*.
const KEY_DEPLOYS: String = "UI_TREE_DEPLOYS"
const KEY_DEPLOYS_ROW: String = "UI_TREE_DEPLOYS_ROW"
const KEY_GRANTS: String = "UI_TREE_GRANTS"
const KEY_REQUIRES_ASSETS: String = "UI_TREE_REQUIRES_ASSETS"
## accessibility.md §6.3 item 3: a missing row says so in words, not in red alone.
const KEY_REQUIRES_ASSETS_MISSING: String = "UI_TREE_REQUIRES_ASSETS_MISSING"
const KEY_EXCLUDES: String = "UI_TREE_EXCLUDES"
const KEY_GROUP: String = "UI_TREE_GROUP"
const KEY_BUY_PLACE: String = "UI_TREE_BUY_PLACE"
const PREFIX_GROUP: String = "GROUP_"
const PREFIX_ABILITY: String = "ABILITY_"
const SUFFIX_NAME: String = "_NAME"
const VARIATION_CAPS: StringName = &"LabelCaps"
const VARIATION_ALERT: StringName = &"LabelCaptionAlert"

## The tab names, by tree id — the chip in the caption row and the `in {tab}`
## suffix of a prerequisite from elsewhere.
const TAB_KEY: Dictionary[String, String] = {
	"infiltration": "UI_TREE_TAB_INFILTRATION",
	"capabilities": "UI_TREE_TAB_CAPABILITIES",
	"evasion": "UI_TREE_TAB_EVASION",
}
## The state chip, in the order of `TechNode.State`.
const STATE_KEY: Array[String] = ["UI_TREE_STATE_LOCKED", "UI_TREE_STATE_AVAILABLE",
	"UI_TREE_STATE_AFFORDABLE", "UI_TREE_STATE_OWNED", "UI_TREE_STATE_EXCLUDED",
	"UI_TREE_STATE_CLOSED"]
const STATE_IS_ACCENT: Array[bool] = [false, false, true, true, false, false]

@onready var _empty_hint: Label = %EmptyHint
@onready var _effects_title: Label = %EffectsTitle
@onready var _requires_title: Label = %RequiresTitle
@onready var _requires_any_title: Label = %RequiresAnyTitle
@onready var _requires_any_hint: Label = %RequiresAnyHint
@onready var _body: Control = %Body
@onready var _title: Label = %Title
@onready var _title_icon: IconRect = %TitleIcon
@onready var _tier: Label = %Tier
@onready var _tree_chip: Chip = %TreeChip
@onready var _state_chip: Chip = %StateChip
@onready var _group_chip: Chip = %GroupChip
@onready var _effect: Label = %Effect
@onready var _flavour: Label = %Flavour
@onready var _effects: VBoxContainer = %Effects
@onready var _requires_block: Control = %RequiresBlock
@onready var _requires: VBoxContainer = %Requires
@onready var _requires_any_block: Control = %RequiresAnyBlock
@onready var _requires_any: VBoxContainer = %RequiresAny
@onready var _v3_rows: VBoxContainer = %V3Rows
@onready var _watched: HFlowContainer = %Watched
@onready var _watched_none: Label = %WatchedNone
@onready var _buy: ConsoleButton = %Buy
@onready var _owned_chip: Chip = %OwnedChip
@onready var _locked_hint: Label = %LockedHint
@onready var _failure: Label = %Failure
@onready var _close_button: IconButton = %DetailClose

var _node_id: String = ""


func _ready() -> void:
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(get_node("Scroll") as ScrollContainer)
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
	_fill_head(definition, state, sim)
	_fill_effects(definition, sim.db)
	_fill_prerequisites(definition, sim)
	_fill_v3(definition, sim)
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


func _fill_head(definition: TechNodeDef, state: TechNode.State, sim: Simulation) -> void:
	_title.text = TechText.node_name(definition.id)
	_title_icon.show_icon(Icons.KIND_TECH, definition.id)
	_tier.text = tr(KEY_TIER).format({"tier": definition.tier})
	_tree_chip.set_label(TAB_KEY[definition.tree])
	_state_chip.set_label(STATE_KEY[state], TechNode.state_args(definition, sim))
	_state_chip.kind = Chip.Kind.ACCENT if STATE_IS_ACCENT[state] else Chip.Kind.DEFAULT
	# §16.6: a grouped node says how much of its group is spoken for, whatever
	# state it is in — that is the number the choice is about.
	_group_chip.visible = not definition.group.is_empty()
	if _group_chip.visible:
		_group_chip.set_label(KEY_GROUP, {
			"group": tr(PREFIX_GROUP + definition.group.to_upper()),
			"owned": sim.owned_in_group(definition.group),
			"max": sim.group_max(definition.group),
		})
	_effect.text = tr(KEY_EFFECT % definition.id.to_upper())
	_flavour.text = tr(KEY_FLAVOUR % definition.id.to_upper())


## One caption per modifier, flag and one-shot, in the order the data lists them.
func _fill_effects(definition: TechNodeDef, db: ContentDB) -> void:
	_clear(_effects)
	for modifier: ModifierDef in definition.modifiers:
		_add_caption(_effects, TechText.modifier_line(modifier, db))
	for flag: String in definition.flags:
		_add_caption(_effects, TechText.flag_line(flag))
	for effect: EffectDef in definition.on_purchase:
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
	# The excluded and closed states name a group or a node (S4.9 screenshots).
	state.set_label(STATE_KEY[node_state], TechNode.state_args(definition, sim))
	state.kind = Chip.Kind.ACCENT if STATE_IS_ACCENT[node_state] else Chip.Kind.DEFAULT
	row.add_child(state)
	if definition.tree != tree:
		var elsewhere: Label = Label.new()
		elsewhere.theme_type_variation = &"LabelCaption"
		elsewhere.text = tr(KEY_IN_TAB).format({"tab": tr(TAB_KEY[definition.tree])})
		row.add_child(elsewhere)
	return row


## §16.6: *Deploys*, *Grants*, *Needs assets* and *Excludes*, each only when the
## node carries it. They are built rather than laid out in the scene, because a
## node has none of them as often as it has one.
func _fill_v3(definition: TechNodeDef, sim: Simulation) -> void:
	_clear(_v3_rows)
	if definition.deploys():
		_add_heading(KEY_DEPLOYS)
		_add_row(tr(KEY_DEPLOYS_ROW).format({
			"count": definition.deploy_count,
			"kind": TechText.asset_name(definition.deploy_kind, definition.deploy_count),
		}))
		for line: String in NodeLockText.needs(definition):
			_add_caption(_v3_rows, line)
	if definition.grants_ability():
		# One key, not a heading and a row: `UI_TREE_GRANTS` is the whole
		# sentence (§16.6). The heading it used to get printed its own
		# placeholders, which nothing saw until a live node granted an ability.
		_add_row(tr(KEY_GRANTS).format({
			"ability": tr(PREFIX_ABILITY + definition.ability_id.to_upper() + SUFFIX_NAME),
			"level": definition.ability_level,
		}))
	if not definition.requires_assets.is_empty():
		var missing: Dictionary[String, int] = sim.missing_assets(definition)
		for kind: String in definition.requires_assets:
			var count: int = definition.requires_assets[kind]
			var line: Label = _add_row(tr(KEY_REQUIRES_ASSETS_MISSING if missing.has(kind)
				else KEY_REQUIRES_ASSETS).format({
					"count": count,
					"kind": TechText.asset_name(kind, count),
				}))
			if missing.has(kind):
				line.theme_type_variation = VARIATION_ALERT
	if not definition.excludes.is_empty():
		_add_heading(KEY_EXCLUDES)
		for other: String in definition.excludes:
			var line: Label = _add_row(TechText.node_name(other))
			line.theme_type_variation = VARIATION_ALERT


func _add_heading(key: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = VARIATION_CAPS
	label.text = Format.caps(tr(key))
	_v3_rows.add_child(label)


func _add_row(text: String) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_v3_rows.add_child(label)
	return label


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
	# Punch item 4 (S6.P3b): not "requirements not met" but which, and every
	# other reason the purchase would be refused for, one line each.
	var reasons: PackedStringArray = NodeLockText.reasons(definition, sim)
	_locked_hint.visible = not owned and not reasons.is_empty()
	_locked_hint.text = "\n".join(reasons)
	if owned:
		_owned_chip.set_label(KEY_OWNED if purchase_day < 0 else KEY_OWNED_DAY,
			{"day": Format.number(float(purchase_day), Format.Kind.DAYS)})
		return
	# §16.6: on a deploying node the button opens site select instead of buying,
	# so it is enabled when everything but the site is fine.
	var key: String = KEY_BUY_PLACE if definition.deploys() else KEY_BUY
	var buy_text: String = tr(key).format({"cost": Format.number(cost, Format.Kind.COMPUTE)})
	_buy.text = Format.caps(buy_text)
	# accessibility.md §3.2 item 7: the name is not the uppercased copy.
	_buy.accessibility_name = buy_text
	var reason: String = sim.can_apply(PurchaseNodeCommand.new(definition.id))
	_buy.disabled = not (reason.is_empty()
		or (definition.deploys() and reason == Command.FAIL_SITE_REQUIRED))


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
