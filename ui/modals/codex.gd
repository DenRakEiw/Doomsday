extends Control
## The Codex (spec `screens-full.md` §6.1): seven tabs that fill as you play,
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

## The tab row wraps rather than scrolls (§6.1 asks for a scroll in compact):
## seven tabs do not fit a 560 px modal either, and a wrapped row hides none.

## The tab on show and the entry open in it ("" = none).
var tab: String = CodexEntries.TAB_REGIONS
var entry_id: String = ""

var _db: ContentDB = null
var _tab_group: ButtonGroup = ButtonGroup.new()
var _tab_buttons: Dictionary[String, ConsoleButton] = {}
var _compact: bool = false


func _ready() -> void:
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
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _db != null:
		show_tab(tab)


## Opens on the first tab, read fresh from the profile.
func open() -> void:
	_db = Game.content()
	_title.text = tr(KEY_TITLE)
	visible = true
	show_tab(CodexEntries.TAB_REGIONS)
	_fit()


func on_escape() -> void:
	closed.emit()


func show_tab(id: String) -> void:
	if _db == null or not CodexEntries.TABS.has(id):
		return
	tab = id
	_tab_buttons[id].set_pressed_no_signal(true)
	var ids: Array[String] = CodexEntries.ids(tab, _db)
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
			_heading(tr(StatusDef.name_key(id)))
			_caps(tr(StatusDef.code_key(id)))
			_body(tr(StatusDef.detail_key(id)))
		CodexEntries.TAB_ARCHITECTURES:
			_fill_architecture(id)
		CodexEntries.TAB_ENDINGS:
			_heading(tr(PREFIX_OUTCOME + CodexEntries.outcome_of(id).to_upper()))
			_body(tr(EndingLineDef.verdict_key(id)))
	_entry_scroll.scroll_vertical = 0
	if _compact:
		_list_scroll.visible = false
		_entry_scroll.visible = true
		_back.visible = true


## The name an entry is listed under.
func entry_name(which: String, id: String) -> String:
	match which:
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
	_heading(tr(PREFIX_FACTION + id.to_upper()))
	_body(tr(KEY_FACTION_TEXT % id.to_upper()))
	var seen: Array = ProfileManager.codex.get(CodexTracker.TAB_MOVES, [])
	var names: Array[String] = []
	for def: EventDef in _db.events:
		if def.kind == EventDef.KIND_COUNTER_MOVE and def.faction == id and seen.has(def.id):
			names.append(tr(EventDef.title_key(def.id)))
	if names.is_empty():
		return
	_caps(tr(KEY_MOVES))
	for text: String in names:
		_caption(text)


## §6.1: the tech card as the tree's detail pane shows it, without cost or
## buttons — name, tree, effect, flavour, and the effect lines.
func _fill_tech(id: String) -> void:
	var def: TechNodeDef = _db.tech(id)
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


func _fill_architecture(id: String) -> void:
	var def: ArchitectureDef = _db.architecture(id)
	_heading(tr(ArchitectureDef.name_key(id)))
	if not ProfileManager.is_unlocked(def):
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
	if was_compact != _compact and _db != null:
		show_tab(tab)
