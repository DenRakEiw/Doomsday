class_name EventOptions
extends VBoxContainer
## The answers to one map event, as a stack of full-width buttons
## (`loop-mechanics.md` §16.5 item 12, §16.7).
##
## The event card in the region panel and the wire card show the same list, so
## it is one component: a button per option with its text and a trailing price
## chip; under it the generated line of what the answer does
## (plain-language.md §5.2 C1), and a caption — why it is locked, that the
## Compute is short, or that this is what happens if you wait. Pressing asks; the
## owner sends the command and hands a refusal back through `show_failure`.

signal option_chosen(option_id: String)

const KEY_INSUFFICIENT: String = "CMD_FAIL_INSUFFICIENT_COMPUTE"
const PREFIX_FAIL: String = "CMD_FAIL_"
const VARIATION_CAPTION: StringName = &"LabelCaption"
## The effect line reads a step brighter than a caption that only labels: it is
## the answer's explanation (plain-language.md §2.3), in the caption's size.
const VARIATION_EFFECT: StringName = &"LabelCaptionHint"
const VARIATION_ROW: StringName = &"Row"
const VARIATION_STACK: StringName = &"StackTight"

## Option id → the caption under its button, for `show_failure`.
var _captions: Dictionary[String, Label] = {}
## Option id → its button, for the tests and the focus.
var _buttons: Dictionary[String, ConsoleButton] = {}
## Option id → the generated line of what it does (C1).
var _effects: Dictionary[String, Label] = {}


func _ready() -> void:
	theme_type_variation = &"Stack"


## Rebuilds the list for `event` as the world stands. Called on every tick and
## after every command by the owner, so a lock that lifts shows at once.
func show_event(event: OpenEvent, sim: Simulation) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_captions.clear()
	_buttons.clear()
	_effects.clear()
	if event == null or sim == null:
		return
	var def: EventDef = sim.db.event(event.def)
	if def == null:
		return
	for option: EventOptionDef in def.options:
		add_child(_row(def, option, event, sim))


## The button of an option, or null.
func button_of(option_id: String) -> ConsoleButton:
	return _buttons.get(option_id, null)


## The generated line of what an option does, or null (C1).
func effect_of(option_id: String) -> Label:
	return _effects.get(option_id, null)


## The caption under an option, or null.
func caption_of(option_id: String) -> Label:
	return _captions.get(option_id, null)


## The first button that can be pressed — where focus starts (§16.7).
func first_enabled() -> ConsoleButton:
	for child: Node in get_children():
		for button: ConsoleButton in _buttons.values():
			if child.is_ancestor_of(button) and not button.disabled:
				return button
	return null


## A refused answer says why under its own button.
func show_failure(option_id: String, reason: String) -> void:
	var caption: Label = _captions.get(option_id, null)
	if caption == null:
		return
	caption.text = tr(PREFIX_FAIL + reason.to_upper())
	caption.theme_type_variation = &"LabelCaptionAlert"
	caption.visible = true


func _row(def: EventDef, option: EventOptionDef, event: OpenEvent, sim: Simulation) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = VARIATION_STACK
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = VARIATION_ROW
	var lock: Dictionary = option.lock_reason(sim, event.region)
	var short: bool = sim.world.agent.compute < sim.option_cost(option)
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = EventOptionDef.text_key(def.id, option.id)
	button.disabled = not lock.is_empty() or short
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# An answer is up to 40 characters in capitals: on a phone it wraps rather
	# than pushing the card off the screen.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_on_pressed.bind(option.id))
	row.add_child(button)
	var chip: Chip = Chip.new()
	chip.set_text(EventView.cost_text(sim.option_cost(option), option.cost_suppression))
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	box.add_child(row)

	var effect: Label = Label.new()
	effect.theme_type_variation = VARIATION_EFFECT
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.text = OptionText.line(sim, def, option, event.level)
	box.add_child(effect)
	_effects[option.id] = effect

	var caption: Label = Label.new()
	caption.theme_type_variation = VARIATION_CAPTION
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: PackedStringArray = []
	if not lock.is_empty():
		lines.append(EventView.lock_text(lock))
	elif short:
		lines.append(tr(KEY_INSUFFICIENT))
	if option.id == def.default_option:
		lines.append(tr(EventView.KEY_DEFAULT_MARK))
	caption.text = " · ".join(lines)
	caption.visible = not lines.is_empty()
	box.add_child(caption)
	_captions[option.id] = caption
	_buttons[option.id] = button
	return box


func _on_pressed(option_id: String) -> void:
	option_chosen.emit(option_id)
