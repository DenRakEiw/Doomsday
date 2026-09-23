class_name AssetReadout
extends HBoxContainer
## What the agent has on the ground, by kind (`loop-mechanics.md` §16.9).
##
## A caption and one glyph-and-number per kind held anywhere, in
## `AssetDef.KINDS` order. A kind at 0 is hidden; the readout itself appears
## once any asset exists and then stays, because a row that comes and goes is a
## row the eye has to find again (§16.8).
##
## The same component in both layouts: the top bar after the day cell, the
## status strip's second row on a phone.

const KEY_TITLE: String = "UI_HUD_ASSETS"
const KEY_TIP: String = "UI_HUD_ASSETS_TIP"
## §16.3.2: the fleet leads and is drawn larger than the rest.
const GLYPH_LEAD: float = 16.0
const GLYPH: float = 12.0

## Kind → the number beside its glyph.
var _values: Dictionary[String, ValueLabel] = {}
var _icons: Dictionary[String, GlyphIcon] = {}
## Whether this copy is the one its layout uses: the top bar's is off on a
## phone, the status strip's is off above the breakpoint (§16.9).
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			refresh()

## True once anything has ever stood anywhere (§16.8).
var _revealed: bool = false
var _caption: CapsLabel = null


func _ready() -> void:
	theme_type_variation = &"Row"
	tooltip_text = tr(KEY_TIP)
	_caption = CapsLabel.new()
	_caption.label_key = KEY_TITLE
	_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_caption)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.run_started.connect(_on_run_started)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		tooltip_text = tr(KEY_TIP)


## Re-reads the world. Cheap: four kinds and a sum over the regions.
func refresh() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null or Game.db == null:
		visible = false
		return
	if not enabled:
		visible = false
	var any: bool = false
	for kind: String in AssetDef.KINDS:
		var total: int = world.asset_total(kind)
		any = any or total > 0
		_row_for(kind).visible = total > 0
		_icons[kind].visible = total > 0
		if total > 0:
			_values[kind].set_number(float(total), Format.Kind.PLAIN)
	_revealed = _revealed or any
	visible = _revealed and enabled


## Whether the readout has appeared at all, for the reveal test.
func is_revealed() -> bool:
	return _revealed


## A new run starts with nothing on the ground again.
func _on_run_started(_seed_value: int) -> void:
	_revealed = false
	refresh()


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()


## The number beside a kind's glyph, built on first use so that the readout has
## no nodes for kinds the run never holds.
func _row_for(kind: String) -> ValueLabel:
	if _values.has(kind):
		return _values[kind]
	var icon: GlyphIcon = GlyphIcon.new()
	icon.glyph = Glyphs.asset_glyph(Game.db.assets[kind].glyph)
	icon.box_size = GLYPH_LEAD if kind == AssetDef.KIND_FLEET else GLYPH
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(icon)
	var value: ValueLabel = ValueLabel.new()
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(value)
	_icons[kind] = icon
	_values[kind] = value
	return value
