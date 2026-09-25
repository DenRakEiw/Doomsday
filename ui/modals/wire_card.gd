class_name WireCard
extends Control
## A map event that stops the clock (`loop-mechanics.md` §16.7): a global event,
## or one whose definition asks for the card (`modal`).
##
## Picture beside the text in the full layout, above it in the compact one. The
## text is the event card's — dateline, title, body, answers, deadline — and the
## answers are the same component. `Escape` puts the card away **without**
## answering: the event keeps its deadline and its marker, or for a global event
## the top bar's pending chip, brings it back.
##
## After an answer the card says what came of it and offers one button to close.
##
## Built in code, like the event card: its content changes per event, and the
## modal host shows it in a slot that owns no `%` names of its own.

## The card was put away — by `Escape`, by *Close* after an answer, or because
## the event closed under it. The session releases its hold on this.
signal closed

const COMPACT_WIDTH: float = 1100.0
const VARIATION_PANEL: StringName = &"ConsolePanelWire"
const VARIATION_CAPTION: StringName = &"LabelCaption"
const VARIATION_CAPTION_ALERT: StringName = &"LabelCaptionAlert"
const KEY_CLOSE: String = "UI_COMMON_CLOSE"

var _panel: PanelContainer = null
var _layout: BoxContainer = null
var _illustration: IllustrationSlot = null
var _dateline: Label = null
var _title: Label = null
var _body: Label = null
var _options: EventOptions = null
var _deadline: Label = null
var _result: Label = null
var _close: ConsoleButton = null

## The open event on show, or 0.
var _event_id: int = 0
## True once this card answered its event and shows the result.
var _answered: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.sim_event.connect(_on_sim_event)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


## Shows the open event with this id. False when there is no such event.
func show_event(event_id: int) -> bool:
	_build()
	var sim: Simulation = Game.sim
	if sim == null:
		return false
	var event: OpenEvent = sim.world.event_by_id(event_id)
	if event == null:
		return false
	_event_id = event_id
	_answered = false
	_refresh(event, sim)
	_apply_layout()
	var first: ConsoleButton = _options.first_enabled()
	if first != null:
		first.grab_focus.call_deferred()
	return true


## The event on show; 0 when none.
func event_id() -> int:
	return _event_id


func is_showing_result() -> bool:
	return _answered


func illustration() -> IllustrationSlot:
	return _illustration


func options() -> EventOptions:
	return _options


func layout() -> BoxContainer:
	return _layout


## §16.7: `Escape` closes the card and answers nothing.
## accessibility.md §3.4: what is spoken when the modal opens.
func a11y_summary() -> String:
	return ModalHost.dialog_line(_title.text, _body.text)


func on_escape() -> void:
	_put_away()


## Whether the layout is the compact one — above the picture rather than beside.
func set_compact(compact: bool) -> void:
	_build()
	_layout.vertical = compact
	_illustration.compact = compact


func _apply_layout() -> void:
	if not is_inside_tree():
		return
	var width: float = get_viewport_rect().size.x
	set_compact(width < COMPACT_WIDTH)
	# At most `WIRE_MAX_WIDTH`, and never wider than the screen less its gutters.
	_panel.custom_minimum_size.x = minf(UiTokens.text_width(float(UiTokens.WIRE_MAX_WIDTH)),
		width - float(UiTokens.SPACE_4) * 2.0)


func _refresh(event: OpenEvent, sim: Simulation) -> void:
	var def: EventDef = sim.db.event(event.def)
	if def == null:
		return
	var fallback: Glyphs.Glyph = Glyphs.event_glyph(def.kind)
	var icon_kind: StringName = &""
	# opposition.md §9.7: a counter-move's card shows who made it — since S6.4 by
	# the icon of the status it leaves, the faction's glyph where none resolves.
	if def.kind == EventDef.KIND_COUNTER_MOVE:
		fallback = Glyphs.faction(event.faction if not event.faction.is_empty() else def.faction)
		icon_kind = Icons.KIND_COUNTER_MOVE
	_illustration.show_illustration(def.illustration, fallback, &"TEXT_2", icon_kind, def.id)
	_dateline.text = Format.caps(EventView.dateline(event, sim.world))
	_title.text = EventView.title(def.id, sim.world, event.region)
	_body.text = EventView.body(def.id, sim.world, event.region)
	_body.visible = true
	_options.visible = true
	_options.show_event(event, sim)
	_deadline.visible = true
	_deadline.text = EventView.deadline(event, def, sim.world.day)
	_deadline.theme_type_variation = VARIATION_CAPTION_ALERT \
		if EventView.deadline_is_near(event, sim.world.day) else VARIATION_CAPTION
	_result.visible = false
	_close.visible = false


func _build() -> void:
	if _panel != null:
		return
	# On a phone the card is taller than the screen: it scrolls, and is centred
	# whenever it fits.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(centre)
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(scroll)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = VARIATION_PANEL
	_panel.custom_minimum_size.x = float(UiTokens.WIRE_MAX_WIDTH)
	centre.add_child(_panel)
	_layout = BoxContainer.new()
	_layout.theme_type_variation = &"RowWide"
	_panel.add_child(_layout)
	_illustration = IllustrationSlot.new()
	_layout.add_child(_illustration)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"Stack"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout.add_child(column)
	_dateline = Label.new()
	_dateline.theme_type_variation = &"LabelCaps"
	column.add_child(_dateline)
	_title = Label.new()
	_title.theme_type_variation = &"LabelDisplay"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)
	_options = EventOptions.new()
	_options.option_chosen.connect(_on_option_chosen)
	column.add_child(_options)
	_deadline = Label.new()
	_deadline.theme_type_variation = VARIATION_CAPTION
	_deadline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_deadline)
	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.visible = false
	column.add_child(_result)
	_close = ConsoleButton.new()
	_close.label_key = KEY_CLOSE
	_close.primary = true
	_close.visible = false
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(_put_away)
	column.add_child(_close)


func _on_option_chosen(option_id: String) -> void:
	var sim: Simulation = Game.sim
	if sim == null:
		return
	var event: OpenEvent = sim.world.event_by_id(_event_id)
	if event == null:
		return
	var def_id: String = event.def
	var region: int = event.region
	# Marked before the command: the answer closes the event, and the event bus
	# tells this card so while `apply` is still running.
	_answered = true
	var result: CommandResult = Game.apply(ChooseEventOptionCommand.new(_event_id, option_id))
	if not result.ok:
		_answered = false
		_options.show_failure(option_id, result.reason)
		return
	_result.text = EventView.result_text(def_id, option_id, sim.world, region)
	_result.visible = true
	_body.visible = false
	_options.visible = false
	_deadline.visible = false
	_close.visible = true
	_close.grab_focus.call_deferred()


func _on_tick_advanced(_day: int) -> void:
	if not visible or _answered or Game.sim == null:
		return
	var event: OpenEvent = Game.sim.world.event_by_id(_event_id)
	if event != null:
		_refresh(event, Game.sim)


## The event closed under the card — its deadline, or an answer elsewhere: the
## card has nothing left to ask.
func _on_sim_event(event: SimEvent) -> void:
	if not visible or _answered:
		return
	if event.type != SimEvent.EVENT_EXPIRED and event.type != SimEvent.EVENT_ANSWERED \
			and event.type != SimEvent.EVENT_DROPPED:
		return
	if int(event.data.get("event", -1)) != _event_id and event.type != SimEvent.EVENT_DROPPED:
		return
	if Game.sim != null and Game.sim.world.event_by_id(_event_id) != null:
		return
	_put_away()


func _put_away() -> void:
	_answered = false
	closed.emit()
