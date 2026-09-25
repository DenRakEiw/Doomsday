class_name EventCard
extends PanelContainer
## The map event standing in a region, in the region panel
## (`loop-mechanics.md` §16.5 item 12).
##
## Explanation first, flavour under it (plain-language.md §2.3): a dateline with
## the kind, the title, what happens, the answers with the generated line of what
## each does, the deadline, and last the wire copy in the caption's style. A
## counter-move's card wears the border of the faction that made it. After an
## answer the card says what changed and then the result line, for
## `CONSOLE_LINE_MS`, and keeps saying it until the next tick after that — then
## it hides, or shows the next event waiting in the same region.
##
## The card is built in code: it sits inside the region panel's scroll body,
## where `%` names of an authored subtree are the panel's, not the card's.

const VARIATION_PANEL: StringName = &"ConsolePanel"
const VARIATION_CAPTION: StringName = &"LabelCaption"
const VARIATION_CAPTION_ALERT: StringName = &"LabelCaptionAlert"
const VARIATION_CHANGED: StringName = &"LabelCaptionHint"
const VARIATION_CAPS: StringName = &"LabelCaps"
## accessibility.md §6.3 item 4.
const KEY_DATELINE_FACTION: String = "UI_EVENT_DATELINE_FACTION"
const PREFIX_FACTION: String = "FACTION_"

var _dateline: CapsLabel = null
var _title: Label = null
## What happens (§2.3): a counter-move's status, an unplanned behaviour's body,
## an opening's or a story's summary where written.
var _body: Label = null
var _options: EventOptions = null
var _deadline: Label = null
## The wire copy, under the options (§2.3), when the body is not the explanation.
var _wire: Label = null
## "What changed" (§5.2 C2): its heading and its generated lines.
var _changed_title: Label = null
var _changed: Label = null
var _result: Label = null

## The open event on show, or 0.
var _event_id: int = 0
## The event that was just answered here, and until when its result stays.
var _answered_id: int = 0
var _result_until_ms: int = 0


func _ready() -> void:
	theme_type_variation = VARIATION_PANEL
	_build()
	visible = false


## Shows the oldest event standing in `region_index`, or the result of the one
## just answered here, or nothing. Called by the region panel on every refresh.
func show_region(region_index: int) -> void:
	_build()
	var sim: Simulation = Game.sim
	if sim == null or region_index <= 0:
		_hide()
		return
	if _answered_id != 0:
		if Time.get_ticks_msec() < _result_until_ms:
			visible = true
			return
		_answered_id = 0
	var event: OpenEvent = sim.world.event_in_region(region_index)
	if event == null:
		_hide()
		return
	_show(event, sim)


## The event on show, for the tests; 0 when none.
func event_id() -> int:
	return _event_id


func options() -> EventOptions:
	return _options


func deadline_label() -> Label:
	return _deadline


func dateline_label() -> CapsLabel:
	return _dateline


func result_label() -> Label:
	return _result


func body_label() -> Label:
	return _body


func wire_label() -> Label:
	return _wire


func changed_label() -> Label:
	return _changed


func _show(event: OpenEvent, sim: Simulation) -> void:
	var def: EventDef = sim.db.event(event.def)
	if def == null:
		_hide()
		return
	_event_id = event.id
	visible = true
	theme_type_variation = VARIATION_PANEL
	if def.kind == EventDef.KIND_COUNTER_MOVE and not event.faction.is_empty():
		theme_type_variation = StringName(VARIATION_PANEL + Chip.faction_suffix(event.faction))
	# accessibility.md §6.3 item 4: the border's colour is not the only thing
	# that says whose move it is — the dateline names the faction too.
	if event.faction.is_empty():
		_dateline.set_key(EventDef.kind_key(def.kind))
	else:
		_dateline.set_key(KEY_DATELINE_FACTION, {"kind": tr(EventDef.kind_key(def.kind)),
			"faction": tr(PREFIX_FACTION + event.faction.to_upper())})
	_title.text = EventView.title(def.id, sim.world, event.region)
	_body.text = EventView.explanation(def, event, sim)
	_body.visible = true
	_options.visible = true
	_options.show_event(event, sim)
	_deadline.visible = true
	_deadline.text = EventView.deadline(event, def, sim.world.day)
	_deadline.theme_type_variation = VARIATION_CAPTION_ALERT \
		if EventView.deadline_is_near(event, sim.world.day) else VARIATION_CAPTION
	_wire.text = EventView.wire_copy(def, event, sim)
	_wire.visible = not _wire.text.is_empty()
	_show_changed(PackedStringArray())
	_result.visible = false


func _hide() -> void:
	_event_id = 0
	visible = false


func _build() -> void:
	if _title != null:
		return
	var stack: VBoxContainer = VBoxContainer.new()
	stack.theme_type_variation = &"Stack"
	add_child(stack)
	_dateline = CapsLabel.new()
	stack.add_child(_dateline)
	_title = Label.new()
	_title.theme_type_variation = &"LabelHeading"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_body)
	_options = EventOptions.new()
	_options.option_chosen.connect(_on_option_chosen)
	stack.add_child(_options)
	_deadline = Label.new()
	_deadline.theme_type_variation = VARIATION_CAPTION
	_deadline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_deadline)
	_wire = Label.new()
	_wire.theme_type_variation = VARIATION_CAPTION
	_wire.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wire.visible = false
	stack.add_child(_wire)
	_changed_title = Label.new()
	_changed_title.theme_type_variation = VARIATION_CAPS
	_changed_title.visible = false
	stack.add_child(_changed_title)
	_changed = Label.new()
	_changed.theme_type_variation = VARIATION_CHANGED
	_changed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_changed.visible = false
	stack.add_child(_changed)
	# §2.3: the result line is flavour, under what changed.
	_result = Label.new()
	_result.theme_type_variation = VARIATION_CAPTION
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.visible = false
	stack.add_child(_result)


## Sends the answer; a refusal shows under its button. An accepted one turns the
## card into its result line.
func _on_option_chosen(option_id: String) -> void:
	var sim: Simulation = Game.sim
	if sim == null or _event_id == 0:
		return
	var event: OpenEvent = sim.world.event_by_id(_event_id)
	if event == null:
		return
	var def_id: String = event.def
	var region: int = event.region
	# Marked before the command: the panel re-reads on `command_applied` while
	# `apply` is still running, and must find the card showing a result, not an
	# event that is gone.
	var answered: int = _event_id
	_answered_id = answered
	_result_until_ms = Time.get_ticks_msec() + UiTokens.CONSOLE_LINE_MS
	var result: CommandResult = Game.apply(ChooseEventOptionCommand.new(answered, option_id))
	if not result.ok:
		_answered_id = 0
		_options.show_failure(option_id, result.reason)
		return
	visible = true
	var day: int = sim.world.day
	_show_changed(ChangeText.lines(result.events, day))
	_result.text = EventView.result_text(def_id, option_id, sim.world, region,
		ChangeText.result_args(result.events, day))
	_result.visible = true
	_body.visible = false
	_options.visible = false
	_deadline.visible = false
	_wire.visible = false


## §5.2 C2: the generated lines of what the answer changed, under a heading;
## nothing at all when it changed nothing the player can see.
func _show_changed(lines: PackedStringArray) -> void:
	_changed_title.text = Format.caps(tr(ChangeText.KEY_TITLE))
	_changed.text = "\n".join(lines)
	_changed.visible = not lines.is_empty()
	_changed_title.visible = _changed.visible
