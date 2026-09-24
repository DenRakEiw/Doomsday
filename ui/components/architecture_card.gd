class_name ArchitectureCard
extends Button
## One architecture on the setup screen (spec `screens-full.md` §4.1): a toggle
## card with a glyph, the name and the tagline — or, while it is locked, the
## rule that unlocks it.
##
## The glyph is M6 art (`Glyphs` id `arch_<id>`); until then it is the first
## letter of the name.

const VARIATION: StringName = &"ArchitectureCard"
const KEY_TAGLINE: String = "ARCH_%s_TAGLINE"
const KEY_NEW: String = "UI_SETUP_NEW"

## The content id this card stands for.
var architecture_id: String = ""
var locked: bool = false

var _glyph: Label = null
var _name: Label = null
var _tagline: Label = null
var _new_chip: Chip = null
## The unlock rule's text, shown in place of the tagline while locked.
var _rule_text: String = ""


func _init() -> void:
	theme_type_variation = VARIATION
	toggle_mode = true
	clip_text = false
	_build()


## What the card shows: `rule_text` is the unlock rule (only read while
## `is_locked`), `is_new` puts the *New* chip on it.
func setup(id: String, is_locked: bool, rule_text: String, is_new: bool) -> void:
	architecture_id = id
	locked = is_locked
	_rule_text = rule_text
	disabled = is_locked
	_new_chip.visible = is_new and not is_locked
	_refresh_strings()


func set_new(is_new: bool) -> void:
	_new_chip.visible = is_new and not locked


func is_new() -> bool:
	return _new_chip.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _name != null:
		_refresh_strings()


func _refresh_strings() -> void:
	if architecture_id.is_empty():
		return
	var name_text: String = tr(ArchitectureDef.name_key(architecture_id))
	_name.text = name_text
	_glyph.text = name_text.left(1).to_upper()
	_tagline.text = _rule_text if locked else tr(KEY_TAGLINE % architecture_id.to_upper())
	accessibility_name = "%s. %s" % [name_text, _tagline.text]


func _build() -> void:
	var content: MarginContainer = MarginContainer.new()
	content.theme_type_variation = &"GutterTight"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"StackTight"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)
	var head: HBoxContainer = HBoxContainer.new()
	head.theme_type_variation = &"Row"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_glyph = _label(&"LabelDisplay", head)
	_name = _label(&"LabelHeading", head)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_new_chip = Chip.new()
	_new_chip.kind = Chip.Kind.ACCENT
	_new_chip.label_key = KEY_NEW
	_new_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_new_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_chip.visible = false
	head.add_child(_new_chip)
	_tagline = _label(&"LabelCaption", column)
	_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ButtonContent.fit(self, content, false, true)


static func _label(variation: StringName, into: Control) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(label)
	return label
