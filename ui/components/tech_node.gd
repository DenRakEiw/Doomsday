class_name TechNode
extends Button
## One node of a technology tree (spec m3-screens.md §3.4).
##
## A `Button`, so focus, hover, keyboard activation and the accessible name come
## free. The four states are theme variations, never per-node overrides; the two
## things a variation cannot do — the white selection border and the purchase
## flash — are drawn here, over the button's own surface.
##
## The node computes nothing about the run: the modal hands it its state.

## `EXCLUDED` and `CLOSED` are appended rather than inserted, because every
## table below is indexed by the enum value (`loop-mechanics.md` §16.6). They
## rank below `OWNED` and above `LOCKED`, and a node that is both takes
## `CLOSED`.
enum State { LOCKED, AVAILABLE, AFFORDABLE, OWNED, EXCLUDED, CLOSED }

## Selected by a tap, a click or `Enter`.
signal selected(node_id: String)
## `Enter` on a node that is affordable (§3.3).
signal buy_requested(node_id: String)

const VARIATION: String = "TechNode"
## Suffixes on the variation names, in the order of `State`.
const STATE_SUFFIX: Array[String] = ["Locked", "", "Affordable", "Owned", "Locked", "Locked"]
## The name and the cost take their colour from the state too, and a `Label` has
## one colour — so each is its own family (§3.4's table).
const NAME_VARIATION: Array[String] = ["TechNodeNameLocked", "TechNodeName", "TechNodeName",
	"TechNodeName", "TechNodeNameLocked", "TechNodeNameLocked"]
const NAME_LOCKED: String = "TechNodeNameLocked"
const MARGIN_LEFT: StringName = &"margin_left"
const MARGIN_RIGHT: StringName = &"margin_right"
const COST_VARIATION: Array[String] = ["TechNodeCostLocked", "TechNodeCost",
	"TechNodeCostAffordable", "TechNodeCost", "TechNodeCostLocked", "TechNodeCostLocked"]
## The accessible state names, in the order of `State`.
const STATE_KEY: Array[String] = ["UI_TREE_STATE_LOCKED", "UI_TREE_STATE_AVAILABLE",
	"UI_TREE_STATE_AFFORDABLE", "UI_TREE_STATE_OWNED", "UI_TREE_STATE_EXCLUDED",
	"UI_TREE_STATE_CLOSED"]

const KEY_NAME: String = "TECH_%s_NAME"
const KEY_A11Y: String = "UI_TREE_NODE_A11Y"
const KEY_OWNED: String = "UI_TREE_OWNED"
const KEY_FOOTPRINT: String = "UI_TREE_FP"
const TARGET_FOOTPRINT: String = "footprint"
## The name never becomes an ellipsis: two lines are enough in both languages,
## and `tests/unit/test_tech_node.gd` is what keeps that true.
const NAME_LINES: int = 2

## The content id this node stands for.
@export var node_id: String = ""

var state: State = State.LOCKED
var has_external_prerequisite: bool = false

@onready var _name: CapsLabel = %NodeName
@onready var _cost: ValueLabel = %NodeCost
@onready var _owned_tag: Label = %OwnedTag
@onready var _footprint: Label = %Footprint
@onready var _glyph_box: Control = %GlyphBox
@onready var _icon: IconRect = %NodeIcon
@onready var _content: MarginContainer = $Content
@onready var _footer: HBoxContainer = $Content/Column/Footer

var _cell: Vector2i = Vector2i.ZERO
var _is_selected: bool = false
var _flash_alpha: float = 0.0
var _flash_tween: Tween = null
## Kept so that the accessible name can be rebuilt on a locale change.
var _cost_value: float = 0.0
## The placeholders the state's string takes; empty for a state without any.
var _state_args: Dictionary = {}


func _ready() -> void:
	_name.max_lines_visible = NAME_LINES
	_glyph_box.custom_minimum_size = Vector2(float(UiTokens.GLYPH_BOX),
		float(UiTokens.GLYPH_BOX))
	for state_signal: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		state_signal.connect(queue_redraw)
	# The glyph is drawn into the footer's box, and the first `_draw` happens
	# before the layout has put that box anywhere.
	_glyph_box.item_rect_changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	resized.connect(_fit_icon)
	pressed.connect(_on_pressed)
	_apply_state()
	# The palette can change mid-run (m3-screens §6.2); a drawn colour is not
	# a theme item and has to be asked for again.
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)


func _on_theme_variant_changed(_variant: StringName) -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_strings()
	elif what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


## Everything the node shows, in one call from the modal.
func bind(definition: TechNodeDef, cost: float, node_state: State, external: bool,
		state_arguments: Dictionary = {}) -> void:
	node_id = definition.id
	_icon.show_icon(Icons.KIND_TECH, definition.id)
	_state_args = state_arguments
	_cell = definition.grid
	state = node_state
	has_external_prerequisite = external
	_cost_value = cost
	_name.label_key = KEY_NAME % definition.id.to_upper()
	var footprint: float = _footprint_of(definition)
	_footprint.visible = not is_zero_approx(footprint)
	if _footprint.visible:
		_footprint.text = tr(KEY_FOOTPRINT).format({"fp": _signed(footprint)})
	_apply_state()


func set_selected(value: bool) -> void:
	if value == _is_selected:
		return
	_is_selected = value
	queue_redraw()


func is_selected() -> bool:
	return _is_selected


## The border lights up and fades back to the state's own (§3.3).
func flash() -> void:
	var seconds: float = UiTokens.duration(UiTokens.MOTION_FLASH)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_alpha = 0.0
	queue_redraw()
	if seconds <= 0.0 or not is_inside_tree():
		return
	_flash_alpha = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash_alpha, 1.0, 0.0, seconds)


func grid_cell() -> Vector2i:
	return _cell


## The state §3.4 gives a node, read from the simulation and nothing else. It
## lives here because the node owns the enum and three screens ask for it.
static func state_for(definition: TechNodeDef, sim: Simulation) -> State:
	if sim.world.agent.owns(definition.id):
		return State.OWNED
	if not sim.excluded_by(definition.id).is_empty():
		return State.CLOSED
	if not definition.group.is_empty() \
			and sim.owned_in_group(definition.group) >= sim.group_max(definition.group):
		return State.EXCLUDED
	# A deploying node is affordable when everything but the site is fine: the
	# site is chosen after the button, not before it (§16.6).
	var reason: String = sim.can_apply(PurchaseNodeCommand.new(definition.id))
	if reason.is_empty() or reason == Command.FAIL_SITE_REQUIRED:
		return State.AFFORDABLE
	if sim.prerequisites_met(definition):
		return State.AVAILABLE
	return State.LOCKED


## The placeholders the state's own string takes, for the chip and the
## accessible name. Empty for the four states that need none.
static func state_args(definition: TechNodeDef, sim: Simulation) -> Dictionary:
	match state_for(definition, sim):
		State.CLOSED:
			return {"node": TechText.node_name(sim.excluded_by(definition.id))}
		State.EXCLUDED:
			return {
				"group": TechText.tr_key("GROUP_" + definition.group.to_upper()),
				"owned": sim.owned_in_group(definition.group),
				"max": sim.group_max(definition.group),
			}
	return {}


## The glyph the footer shows, or -1 for none (§3.4).
func glyph() -> int:
	if state == State.OWNED:
		return Glyphs.Glyph.CHECK
	if state == State.EXCLUDED or state == State.CLOSED:
		return Glyphs.Glyph.LOCK
	if state != State.LOCKED:
		return -1
	return Glyphs.Glyph.EXTERNAL if has_external_prerequisite else Glyphs.Glyph.LOCK


## Whether the footer shows the node's icon — false when it has no file, or when
## the compact cell has no room for it (see `_fit_icon`).
func shows_icon() -> bool:
	return _icon.visible


## icons.md §7 expected the icon to fit the compact cell with everything else in
## the footer; at 160 px a locked node with a footprint and the external glyph
## needs 152 of the 136 px there are. The text carries the meaning (§6), so the
## icon is what gives way.
# D6.8 kept this as the rule: the icon steps aside when the footer would
# overflow its cell — the detail pane always shows it.
func _fit_icon() -> void:
	if not is_node_ready():
		return
	_icon.visible = not Icons.path_for(Icons.KIND_TECH, node_id).is_empty()
	if not _icon.visible or size.x <= 0.0:
		return
	var room: float = size.x - float(_content.get_theme_constant(MARGIN_LEFT)) \
		- float(_content.get_theme_constant(MARGIN_RIGHT))
	_icon.visible = _footer.get_combined_minimum_size().x <= room


func _draw() -> void:
	_draw_glyph()
	if _is_selected:
		_draw_border(UiTokens.color(&"MAP_SELECT"), float(UiTokens.BORDER_FOCUS))
	if _flash_alpha > 0.0:
		_draw_border(Color(UiTokens.color(&"ACCENT"), _flash_alpha), float(UiTokens.BORDER_FOCUS))


func _draw_glyph() -> void:
	var shape: int = glyph()
	if shape < 0 or _glyph_box == null:
		return
	var box: Rect2 = Rect2(_glyph_box.global_position - global_position, _glyph_box.size)
	Glyphs.draw(self, shape as Glyphs.Glyph, box, _glyph_colour(), UiTokens.GLYPH_STROKE)


func _glyph_colour() -> Color:
	return UiTokens.color(&"ACCENT") if state == State.OWNED else UiTokens.color(&"TEXT_2")


func _draw_border(colour: Color, width: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), colour, false, width)


func _set_flash_alpha(value: float) -> void:
	_flash_alpha = value
	queue_redraw()


## `Enter` buys what it can afford and selects the rest (§3.3). A click only ever
## selects — one verb per gesture.
func _gui_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.is_action(&"ui_accept"):
		return
	selected.emit(node_id)
	if state == State.AFFORDABLE:
		buy_requested.emit(node_id)
	accept_event()


func _on_pressed() -> void:
	selected.emit(node_id)


func _apply_state() -> void:
	theme_type_variation = StringName(VARIATION + STATE_SUFFIX[state])
	if is_node_ready():
		_name.theme_type_variation = StringName(NAME_VARIATION[state])
		# icons.md §7: the icon takes the name's colour — dim where the name is.
		_icon.color_token = &"TEXT_2" if NAME_VARIATION[state] == NAME_LOCKED else &"TEXT_0"
		_cost.variation_base = StringName(COST_VARIATION[state])
		# An owned node has no price any more; it has a date (§3.4).
		_cost.visible = state != State.OWNED
		_owned_tag.visible = state == State.OWNED
		_cost.set_number(_cost_value, Format.Kind.COMPUTE)
		_owned_tag.text = tr(KEY_OWNED)
	_refresh_strings()
	_fit_icon()
	queue_redraw()


func _refresh_strings() -> void:
	accessibility_name = tr(KEY_A11Y).format({
		"name": tr(KEY_NAME % node_id.to_upper()),
		"state": tr(STATE_KEY[state]).format(_state_args),
		"cost": Format.number(_cost_value, Format.Kind.COMPUTE),
	})


## The node's own unscoped footprint, which is what the footer promises: a scoped
## one is a number about somewhere else and belongs in the detail pane.
static func _footprint_of(definition: TechNodeDef) -> float:
	var total: float = 0.0
	for modifier: ModifierDef in definition.modifiers:
		if modifier.target == TARGET_FOOTPRINT and modifier.op == ModifierDef.Op.ADD \
				and modifier.scope_kind == ModifierDef.ScopeKind.NONE:
			total += modifier.value
	return total


## The same arrows a `ValueLabel` uses: the footer is a number with a direction,
## and the player has already learnt what the shapes mean.
static func _signed(value: float) -> String:
	if value > 0.0:
		return "%s %s%s" % [ValueLabel.ARROW_UP, ValueLabel.PLUS,
			Format.number(value, Format.Kind.COMPUTE)]
	return "%s %s" % [ValueLabel.ARROW_DOWN, Format.number(value, Format.Kind.COMPUTE)]
