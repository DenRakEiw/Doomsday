extends Control
## The Codex (spec `screens-full.md` §6.1): *How to play* first (`first-run.md`
## §6.6), then eight tabs that fill as you play (*Behaviours* since S6.P4),
## written from strings that already exist, plus four factions and five
## characters of prose of their own.
##
## A locked entry is listed as *Not yet encountered* and cannot be opened —
## except in Endings, where a locked variant is not listed at all, so the hidden
## ending is never named before it is reached.
##
## Scene-specific, so no `class_name`.

signal closed

const KEY_TITLE: String = "UI_CODEX_TITLE"
const KEY_PROGRESS: String = "UI_CODEX_PROGRESS"
const KEY_LOCKED: String = "UI_CODEX_LOCKED"
const KEY_TAB: String = "UI_CODEX_TAB_%s"
const KEY_CONTINENT: String = "UI_CODEX_CONTINENT"
const KEY_POPULATION: String = "UI_CODEX_POPULATION"
const KEY_MOVES: String = "UI_CODEX_MOVES"
const KEY_FACTION_TEXT: String = "CODEX_FACTION_%s"
const KEY_CHARACTER_NAME: String = "CODEX_CHARACTER_%s_NAME"
const KEY_CHARACTER_TEXT: String = "CODEX_CHARACTER_%s_TEXT"
const KEY_ARCH_TAGLINE: String = "ARCH_%s_TAGLINE"
const KEY_ARCH_DETAIL: String = "ARCH_%s_DETAIL"
const KEY_TECH_EFFECT: String = "TECH_%s_EFFECT"
const KEY_TECH_FLAVOUR: String = "TECH_%s_FLAVOUR"
## plain-language.md §5.2 C7: what an unplanned behaviour's name means, keyed by
## its status id (`CODEX_EMERGENT_<ID>_TERM`); shown when written.
const KEY_TERM: String = "CODEX_%s_TERM"
## A status with more than one level lists each (C3).
const KEY_STATUS_LEVEL: String = "UI_CODEX_STATUS_LEVEL"
const KEY_UNLOCK_RUNS: String = "UI_SETUP_UNLOCK_RUNS"
const KEY_UNLOCK_WIN: String = "UI_SETUP_UNLOCK_WIN"
const KEY_UNLOCK_WIN_BY: String = "UI_SETUP_UNLOCK_WIN_BY"
const PREFIX_REGION: String = "REGION_"
const PREFIX_CONTINENT: String = "CONTINENT_"
const PREFIX_FACTION: String = "FACTION_"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
const PREFIX_ATTR: String = "UI_ATTR_"
const PREFIX_TREE_TAB: String = "UI_TREE_TAB_"

@onready var _panel: PanelContainer = %CodexPanel
@onready var _title: Label = %CodexTitle
@onready var _close: IconButton = %CloseButton
@onready var _tabs: HFlowContainer = %Tabs
@onready var _progress: Label = %Progress
@onready var _list_scroll: ScrollContainer = %ListScroll
@onready var _list: VBoxContainer = %List
@onready var _entry_scroll: ScrollContainer = %EntryScroll
@onready var _back: ConsoleButton = %BackButton
@onready var _entry: VBoxContainer = %Entry

## The tab row wraps on a desktop: eight tabs do not fit a 560 px modal, and a
## wrapped row hides none. On a phone it is one row that scrolls sideways
## (accessibility.md §8.2 — at 150 % the wrapped rows took a quarter of the
## screen), the current tab scrolled into view.

## The tab on show and the entry open in it ("" = none).
var tab: String = CodexEntries.TAB_HELP
var entry_id: String = ""
## Where an ending's picture is looked for (`illustrations.md` §8.3). A test
## points it at a folder that has one.
var illustration_root: String = IllustrationSlot.ROOT

var _db: ContentDB = null
var _tab_group: ButtonGroup = ButtonGroup.new()
var _tab_buttons: Dictionary[String, ConsoleButton] = {}
var _compact: bool = false
## §8.2: the phone's one-row strip of tabs.
var _tab_scroll: ScrollContainer = null
var _tab_row: HBoxContainer = null


func _ready() -> void:
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(_list_scroll)
	A11y.focus_scroll(_entry_scroll)
	_close.pressed.connect(closed.emit)
	_back.pressed.connect(_show_list)
	for id: String in CodexEntries.TABS:
		var button: ConsoleButton = ConsoleButton.new()
		button.toggle_mode = true
		button.button_group = _tab_group
		button.compact = true
		button.label_key = KEY_TAB % id.to_upper()
		button.pressed.connect(show_tab.bind(id))
		_tabs.add_child(button)
		_tab_buttons[id] = button
	_build_tab_scroll()
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _db != null:
		# The entry on show stays: the host moving the Codex into its slot sends
		# this too, and a page opened by name (first-run.md §6.7) must survive it.
		var keep: String = entry_id if _entry_scroll.visible else ""
		show_tab(tab)
		if not keep.is_empty() and CodexEntries.ids(tab, _db).has(keep):
			show_entry(keep)


## Opens on `tab_id`, read fresh from the profile, and on `entry` when it is
## given and can be opened — else on the tab's first entry (first-run.md §6.6).
func open(tab_id: String = CodexEntries.TAB_HELP, entry: String = "") -> void:
	_db = Game.content()
	_title.text = tr(KEY_TITLE)
	visible = true
	_fit()
	show_tab(tab_id)
	if not entry.is_empty() and CodexEntries.ids(tab, _db).has(entry):
		show_entry(entry)


func on_escape() -> void:
	closed.emit()


func show_tab(id: String) -> void:
	if _db == null or not CodexEntries.TABS.has(id):
		return
	tab = id
	ToggleGroup.press(_tab_buttons[id])
	# A tab chosen by the code takes the focus ring along from the tab before it.
	var focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus is ConsoleButton and _tab_buttons.values().has(focus):
		_tab_buttons[id].grab_focus()
	if _compact and _tab_scroll != null:
		_tab_scroll.ensure_control_visible.call_deferred(_tab_buttons[id])
	var ids: Array[String] = CodexEntries.ids(tab, _db)
	# §6.6: the pages are not collected, so there is nothing to count.
	_progress.visible = tab != CodexEntries.TAB_HELP
	_progress.text = tr(KEY_PROGRESS).format({"seen": CodexEntries.seen_count(tab, _db),
		"total": ids.size()})
	_clear(_list)
	var first: String = ""
	for entry: String in ids:
		var seen: bool = CodexEntries.is_seen(tab, entry, _db)
		# §6.1: an ending not reached is not listed at all.
		if not seen and tab == CodexEntries.TAB_ENDINGS:
			continue
		var openable: bool = seen or tab == CodexEntries.TAB_ARCHITECTURES
		var row: ConsoleButton = ConsoleButton.new()
		row.list_row = true
		row.toggle_mode = true
		row.text = entry_name(tab, entry) if openable else tr(KEY_LOCKED)
		row.disabled = not openable
		row.set_meta(&"id", entry)
		row.pressed.connect(show_entry.bind(entry))
		_list.add_child(row)
		if openable and first.is_empty():
			first = entry
	entry_id = ""
	_clear(_entry)
	if not _compact and not first.is_empty():
		show_entry(first)
	_show_list()


## Opens one entry of the tab on show. A locked one does not open.
func show_entry(id: String) -> void:
	var openable: bool = CodexEntries.is_seen(tab, id, _db) \
		or tab == CodexEntries.TAB_ARCHITECTURES
	if not openable:
		return
	entry_id = id
	for row: Node in _list.get_children():
		(row as Button).set_pressed_no_signal(str(row.get_meta(&"id")) == id)
	_clear(_entry)
	match tab:
		CodexEntries.TAB_HELP:
			_fill_help(id)
		CodexEntries.TAB_REGIONS:
			_fill_region(id)
		CodexEntries.TAB_FACTIONS:
			_fill_faction(id)
		CodexEntries.TAB_TECH:
			_fill_tech(id)
		CodexEntries.TAB_CHARACTERS:
			_heading(tr(KEY_CHARACTER_NAME % id.to_upper()))
			_body(tr(KEY_CHARACTER_TEXT % id.to_upper()))
		CodexEntries.TAB_STATUSES:
			_fill_status(id)
		CodexEntries.TAB_BEHAVIOURS:
			_fill_behaviour(id)
		CodexEntries.TAB_ARCHITECTURES:
			_fill_architecture(id)
		CodexEntries.TAB_ENDINGS:
			_fill_ending(id)
	_entry_scroll.scroll_vertical = 0
	if _compact:
		_list_scroll.visible = false
		_entry_scroll.visible = true
		_back.visible = true


## The name an entry is listed under.
func entry_name(which: String, id: String) -> String:
	match which:
		CodexEntries.TAB_HELP:
			return tr(HelpPages.title_key(id))
		CodexEntries.TAB_REGIONS:
			return tr(PREFIX_REGION + id.to_upper())
		CodexEntries.TAB_FACTIONS:
			return tr(PREFIX_FACTION + id.to_upper())
		CodexEntries.TAB_TECH:
			return TechText.node_name(id)
		CodexEntries.TAB_CHARACTERS:
			return tr(KEY_CHARACTER_NAME % id.to_upper())
		CodexEntries.TAB_STATUSES:
			return tr(StatusDef.name_key(id))
		CodexEntries.TAB_BEHAVIOURS:
			return tr(EventDef.title_key(id))
		CodexEntries.TAB_ARCHITECTURES:
			return tr(ArchitectureDef.name_key(id))
		CodexEntries.TAB_ENDINGS:
			return tr(PREFIX_OUTCOME + CodexEntries.outcome_of(id).to_upper())
	return id


## Whether the list row for `id` is shown, and whether it can be opened —
## what the tests read.
func row_for(id: String) -> ConsoleButton:
	for row: Node in _list.get_children():
		if str(row.get_meta(&"id")) == id:
			return row as ConsoleButton
	return null


# ------------------------------------------------------------ the entries


## first-run.md §6.6: the title, then the paragraphs `SPACE_3` apart. No icons.
func _fill_help(id: String) -> void:
	_heading(tr(HelpPages.title_key(id)))
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"PanelContent"
	_entry.add_child(column)
	for n: int in range(1, HelpPages.paragraphs(id) + 1):
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = KeyNames.format(tr(HelpPages.paragraph_key(id, n)))
		column.add_child(label)


## A status: its name and code, the plain line on what an unplanned behaviour's
## name means where one is written (plain-language.md §5.2 C7), the detail, and
## per level the generated line of what it does and for how long (C3).
func _fill_status(id: String) -> void:
	_icon(Icons.KIND_STATUS, id, UiTokens.ICON_L, &"TEXT_0")
	_heading(tr(StatusDef.name_key(id)))
	_caps(tr(StatusDef.code_key(id)))
	var term_key: String = KEY_TERM % id.to_upper()
	if tr(term_key) != term_key:
		_body(tr(term_key))
	_body(tr(StatusDef.detail_key(id)))
	var definition: StatusDef = _db.status(id)
	if definition == null:
		return
	var levels: int = definition.levels.size()
	for level: int in range(1, levels + 1):
		var line: String = StatusText.line(_db, id, level)
		if levels > 1:
			line = tr(KEY_STATUS_LEVEL).format({"level": level, "line": line})
		_caption(line)


## plain-language.md §9.3 (S6.P4): an unplanned behaviour as its card tells it —
## the title, what the term means, the body, and each answer with the line of
## what it does (the price a run starts with; keeping names the status, with
## its days and numbers, where there is one).
func _fill_behaviour(id: String) -> void:
	var def: EventDef = _db.event(id)
	if def == null:
		return
	_icon(Icons.KIND_STATUS, id, UiTokens.ICON_L, &"TEXT_0")
	_heading(tr(EventDef.title_key(id)))
	var term_key: String = KEY_TERM % id.to_upper()
	if tr(term_key) != term_key:
		_body(tr(term_key))
	_body(tr(EventDef.body_key(id)))
	for option: EventOptionDef in def.options:
		_caps(tr(EventOptionDef.text_key(id, option.id)))
		_caption(OptionText.line_without_run(_db, def, option))


func _fill_region(id: String) -> void:
	var def: RegionDef = _db.region_by_id(id)
	_heading(tr(PREFIX_REGION + id.to_upper()))
	_pair(KEY_CONTINENT, tr(PREFIX_CONTINENT + def.continent.to_upper()))
	_pair(KEY_POPULATION, Format.number(float(def.population), Format.Kind.COMPACT))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.theme_type_variation = &"Grid"
	_entry.add_child(grid)
	for attribute: String in RegionDef.ATTRIBUTES:
		var name_label: CapsLabel = CapsLabel.new()
		name_label.label_key = PREFIX_ATTR + attribute.to_upper()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var pips: AttributePips = AttributePips.new()
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.tier = int(def.attributes.get(attribute, 0))
		grid.add_child(pips)


func _fill_faction(id: String) -> void:
	# icons.md §7: the faction's chrome icon, its counter-moves' icons on their
	# rows, all in the faction's colour.
	var colour: StringName = UiTokens.FACTION_TOKENS.get(id, &"TEXT_0")
	_icon(Icons.KIND_FACTION, id, UiTokens.ICON_L, colour)
	_heading(tr(PREFIX_FACTION + id.to_upper()))
	_body(tr(KEY_FACTION_TEXT % id.to_upper()))
	var seen: Array = ProfileManager.codex.get(CodexTracker.TAB_MOVES, [])
	var moves: Array[String] = []
	for def: EventDef in _db.events:
		if def.kind == EventDef.KIND_COUNTER_MOVE and def.faction == id and seen.has(def.id):
			moves.append(def.id)
	if moves.is_empty():
		return
	_caps(tr(KEY_MOVES))
	for move: String in moves:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"RowSnug"
		_entry.add_child(row)
		row.add_child(_icon_rect(Icons.KIND_COUNTER_MOVE, move, UiTokens.ICON_ROW, colour))
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = tr(EventDef.title_key(move))
		row.add_child(label)


## §6.1: the tech card as the tree's detail pane shows it, without cost or
## buttons — name, tree, effect, flavour, and the effect lines.
func _fill_tech(id: String) -> void:
	var def: TechNodeDef = _db.tech(id)
	_icon(Icons.KIND_TECH, id, UiTokens.ICON_L, &"TEXT_0")
	_heading(TechText.node_name(id))
	_caps(tr(PREFIX_TREE_TAB + def.tree.to_upper()))
	_body(tr(KEY_TECH_EFFECT % id.to_upper()))
	_caption(tr(KEY_TECH_FLAVOUR % id.to_upper()))
	for modifier: ModifierDef in def.modifiers:
		_caption(TechText.modifier_line(modifier, _db))
	for flag: String in def.flags:
		_caption(TechText.flag_line(flag))
	for effect: EffectDef in def.on_purchase:
		_caption(TechText.effect_line(effect))


## illustrations.md §8.3: the outcome's picture above its name, when the
## ending names one and its file ships — the results screen's rule.
func _fill_ending(id: String) -> void:
	var outcome: String = CodexEntries.outcome_of(id)
	var def: EndingDef = _db.endings.get(outcome, null)
	var slot: IllustrationSlot = IllustrationSlot.new()
	slot.root = illustration_root
	var picture: String = "" if def == null else def.illustration
	if slot.has_file(picture):
		slot.compact = _compact
		_entry.add_child(slot)
		slot.show_illustration(picture, Glyphs.Glyph.OUTCOME)
	else:
		slot.free()
	_heading(tr(PREFIX_OUTCOME + outcome.to_upper()))
	_body(tr(EndingLineDef.verdict_key(id)))


## The entry's picture, or null when it shows none — for the tests.
func entry_illustration() -> IllustrationSlot:
	for child: Node in _entry.get_children():
		if child is IllustrationSlot:
			return child as IllustrationSlot
	return null


func _fill_architecture(id: String) -> void:
	var def: ArchitectureDef = _db.architecture(id)
	var is_unlocked: bool = ProfileManager.is_unlocked(def)
	_icon(Icons.KIND_ARCHITECTURE, id, UiTokens.ICON_XL, &"TEXT_0" if is_unlocked else &"TEXT_2")
	_heading(tr(ArchitectureDef.name_key(id)))
	if not is_unlocked:
		_caption(_unlock_text(def.unlock))
		return
	_caption(tr(KEY_ARCH_TAGLINE % id.to_upper()))
	_body(tr(KEY_ARCH_DETAIL % id.to_upper()))


func _unlock_text(unlock: Dictionary) -> String:
	if unlock.has(ProfileManager.UNLOCK_RUNS):
		return tr(KEY_UNLOCK_RUNS).format({"done": ProfileManager.runs_completed,
			"needed": int(unlock[ProfileManager.UNLOCK_RUNS])})
	if unlock.has(ProfileManager.UNLOCK_WINS):
		return tr(KEY_UNLOCK_WIN)
	var needed: Dictionary = unlock.get(ProfileManager.UNLOCK_WINS_BY_OUTCOME, {})
	var outcome: String = "" if needed.is_empty() else str(needed.keys()[0])
	return tr(KEY_UNLOCK_WIN_BY).format({"outcome": tr(PREFIX_OUTCOME + outcome.to_upper())})


## icons.md §7: an entry's icon above its text. No file, no icon — the rect hides.
func _icon(kind: StringName, id: String, side: int, colour: StringName) -> void:
	_entry.add_child(_icon_rect(kind, id, side, colour))


static func _icon_rect(kind: StringName, id: String, side: int,
		colour: StringName) -> IconRect:
	var icon: IconRect = IconRect.new()
	icon.box_size = float(side)
	icon.color_token = colour
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.show_icon(kind, id)
	return icon


func _heading(text: String) -> void:
	_add(text, &"LabelHeading")


func _body(text: String) -> void:
	_add(text, &"")


func _caption(text: String) -> void:
	_add(text, &"LabelCaption")


func _caps(text: String) -> void:
	_add(Format.caps(text), &"LabelCaps")


func _pair(key: String, value: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"Row"
	_entry.add_child(row)
	var name_label: CapsLabel = CapsLabel.new()
	name_label.label_key = key
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value
	row.add_child(value_label)


func _add(text: String, variation: StringName) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_entry.add_child(label)


static func _clear(box: Control) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------- layout


## The strip the tabs move into on a phone: no scroll bar, the focus followed,
## a margin for the focus ring.
func _build_tab_scroll() -> void:
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.name = "TabScroll"
	_tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_tab_scroll.follow_focus = true
	_tab_scroll.visible = false
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"FocusMargin"
	_tab_scroll.add_child(margin)
	_tab_row = HBoxContainer.new()
	_tab_row.theme_type_variation = &"RowSnug"
	margin.add_child(_tab_row)
	var parent: Node = _tabs.get_parent()
	parent.add_child(_tab_scroll)
	parent.move_child(_tab_scroll, _tabs.get_index() + 1)


## §8.2: the tabs live in the wrapping row on a desktop and in the strip on a
## phone; the current one is scrolled into view.
func _place_tabs() -> void:
	if _tab_scroll == null:
		return
	var home: Container = _tab_row if _compact else _tabs
	for id: String in CodexEntries.TABS:
		var button: ConsoleButton = _tab_buttons[id]
		if button.get_parent() != home:
			button.reparent(home, false)
	_tabs.visible = not _compact
	_tab_scroll.visible = _compact
	if _compact and _tab_buttons.has(tab):
		_tab_scroll.ensure_control_visible.call_deferred(_tab_buttons[tab])


## §6.1: the list beside the entry; in compact the list is a page of its own
## and an entry has *Back*.
func _show_list() -> void:
	_list_scroll.visible = true
	_entry_scroll.visible = not _compact
	_back.visible = false


## The modal is as tall as the window allows, so it does not jump between tabs.
func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	var was_compact: bool = _compact
	_compact = view.x < float(UiTokens.COMPACT_WIDTH)
	_panel.custom_minimum_size.y = maxf(view.y - float(UiTokens.SPACE_6) * 2.0, 0.0)
	_place_tabs()
	if was_compact != _compact and _db != null:
		show_tab(tab)
