extends Control
## The credits and licences (spec `icons.md` §11): who made what the game is
## built from, under which licence, and the licence texts themselves.
##
## Two pages in one modal: the credits, and one entry's licence. An entry is
## listed only when its file ships (`CreditsData.is_visible`), so the screen
## never names what is not in the build.
##
## Scene-specific, so no `class_name`.

signal closed

const KEY_TITLE: String = "UI_CREDITS_TITLE"
const KEY_SECTION_MADE_BY: String = "UI_CREDITS_SECTION_MADE_BY"
const KEY_BY: String = "UI_CREDITS_BY"
const KEY_VIEW_LICENCE: String = "UI_CREDITS_VIEW_LICENCE"
const KEY_A11Y_LICENCE: String = "UI_CREDITS_A11Y_LICENCE"
const KEY_ORIGINAL_LANGUAGE: String = "UI_CREDITS_ORIGINAL_LANGUAGE"
const KEY_ENGINE_NOTICE: String = "UI_CREDITS_ENGINE_NOTICE"
const KEY_ENGINE_COMPONENTS: String = "UI_CREDITS_ENGINE_COMPONENTS"
const KEY_ICONS_BY_AUTHOR: String = "UI_CREDITS_ICONS_BY_AUTHOR"
const KEY_GAME_ICONS_LINE: String = "UI_CREDITS_GAME_ICONS_LINE"
const PLACEHOLDER_NAME: String = "name"
const PLACEHOLDER_AUTHORS: String = "authors"
const SEPARATOR_ROLE: String = " · "
const SEPARATOR_LIST: String = ", "
const COPYRIGHT_MARK: String = "© "
## The game-icons page (§11.2) ends with the vendored notice and the legal code.
const GAME_ICONS_LICENCE: String = "res://assets/icons/game-icons/license.txt"
const CC_BY_LEGAL_CODE: String = "res://assets/licences/CC-BY-3.0.txt"

@onready var _panel: PanelContainer = %CreditsPanel
@onready var _title: Label = %CreditsTitle
@onready var _close: IconButton = %CloseButton
@onready var _credits_scroll: ScrollContainer = %CreditsScroll
@onready var _credits_list: VBoxContainer = %CreditsList
@onready var _licence_page: VBoxContainer = %LicencePage
@onready var _back: ConsoleButton = %BackButton
@onready var _licence_name: Label = %LicenceName
@onready var _licence_note: Label = %LicenceNote
@onready var _licence_scroll: ScrollContainer = %LicenceScroll
@onready var _licence_blocks: VBoxContainer = %LicenceBlocks

## The file the screen reads. A test points it at a fixture.
var path: String = CreditsData.PATH
## The entry whose licence is on show, "" on the credits page.
var licence_id: String = ""

var _data: Dictionary = {}
var _licence_buttons: Dictionary[String, ConsoleButton] = {}


func _ready() -> void:
	_close.pressed.connect(closed.emit)
	_back.pressed.connect(show_credits)
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_refresh()


## Opens on the credits page, the file read fresh.
func open() -> void:
	var result: Dictionary = CreditsData.load_file(path)
	_data = result[CreditsData.KEY_DATA]
	var error: String = result[CreditsData.KEY_ERROR]
	if not error.is_empty():
		# A bad file still shows what it can; the tests are what fail on it.
		push_warning("credits: %s" % error)
	visible = true
	show_credits()
	_fit()


## §11.2: `Escape` on a licence goes back to the credits; on the credits it
## closes.
func on_escape() -> void:
	if licence_id.is_empty():
		closed.emit()
	else:
		show_credits()


func show_credits() -> void:
	var from: String = licence_id
	licence_id = ""
	_title.text = tr(KEY_TITLE)
	_fill_credits()
	_licence_page.visible = false
	_credits_scroll.visible = true
	if _licence_buttons.has(from):
		_licence_buttons[from].grab_focus.call_deferred()


## Opens the licence page of the entry `id`; an entry without one, or one that
## does not show, opens nothing.
func show_licence(id: String) -> void:
	var entry: Dictionary = _entry(id)
	if entry.is_empty() or str(entry["text"]).is_empty() or not CreditsData.is_visible(entry):
		return
	licence_id = id
	_licence_name.text = str(entry["name"])
	_licence_note.text = tr(KEY_ORIGINAL_LANGUAGE)
	_clear(_licence_blocks)
	var text: String = str(entry["text"])
	match text:
		CreditsData.TEXT_ENGINE:
			_fill_engine()
		CreditsData.TEXT_GAME_ICONS:
			_fill_game_icons()
		_:
			_block(_read(text))
	_credits_scroll.visible = false
	_licence_page.visible = true
	_licence_scroll.scroll_vertical = 0
	_back.grab_focus.call_deferred()


## The ids of the entries listed, in order — what the tests read.
func listed_ids() -> Array[String]:
	var out: Array[String] = []
	for section: Dictionary in CreditsData.visible_sections(_data):
		for entry: Dictionary in CreditsData.visible_entries(section):
			out.append(str(entry["id"]))
	return out


## The licence button of an entry, or null when it has none.
func licence_button(id: String) -> ConsoleButton:
	return _licence_buttons.get(id, null)


## The texts of the licence page's blocks and headings, in order.
func licence_texts() -> Array[String]:
	var out: Array[String] = []
	for child: Node in _licence_blocks.get_children():
		out.append((child as Label).text)
	return out


func _refresh() -> void:
	if licence_id.is_empty():
		show_credits()
	else:
		show_licence(licence_id)


# ------------------------------------------------------------ the credits


func _fill_credits() -> void:
	_clear(_credits_list)
	_licence_buttons.clear()
	var made_by: Array = _data.get("made_by", [])
	if not made_by.is_empty():
		var box: VBoxContainer = _section(KEY_SECTION_MADE_BY)
		for who: Variant in made_by:
			var label: Label = Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text = str(who)
			box.add_child(label)
	for section: Dictionary in CreditsData.visible_sections(_data):
		var box: VBoxContainer = _section(CreditsData.PREFIX_SECTION
			+ str(section["id"]).to_upper())
		for entry: Dictionary in CreditsData.visible_entries(section):
			_add_entry(box, entry)


func _section(heading_key: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.theme_type_variation = &"StackTight"
	_credits_list.add_child(box)
	var heading: Label = Label.new()
	heading.theme_type_variation = &"LabelHeading"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.text = tr(heading_key)
	box.add_child(heading)
	return box


## §11.2 items 1–5: name and maker, role and licence, the address, the
## attribution line, the licence button.
func _add_entry(box: VBoxContainer, entry: Dictionary) -> void:
	var lines: VBoxContainer = VBoxContainer.new()
	lines.theme_type_variation = &"StackLines"
	box.add_child(lines)
	var head: HFlowContainer = HFlowContainer.new()
	head.theme_type_variation = &"FlowSnug"
	lines.add_child(head)
	var name_label: Label = Label.new()
	name_label.text = str(entry["name"])
	head.add_child(name_label)
	var by: String = str(entry["by"])
	if not by.is_empty():
		var by_label: Label = Label.new()
		by_label.theme_type_variation = &"LabelCaption"
		by_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		by_label.text = tr(KEY_BY).format({PLACEHOLDER_NAME: by})
		head.add_child(by_label)
	_caption(lines, tr(str(entry["role"])) + SEPARATOR_ROLE
		+ tr(CreditsData.PREFIX_LICENCE + str(entry["licence"]).to_upper()), &"LabelCaptionHint")
	var url: String = str(entry["url"])
	if not url.is_empty():
		# Selectable text, not a link: no browser jump on the web or a phone.
		var address: RichTextLabel = RichTextLabel.new()
		address.theme_type_variation = &"CaptionSelectable"
		address.bbcode_enabled = false
		address.fit_content = true
		address.scroll_active = false
		address.selection_enabled = true
		address.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		address.text = url
		lines.add_child(address)
	var line_key: String = str(entry["line"])
	if not line_key.is_empty():
		_caption(lines, tr(line_key).format({PLACEHOLDER_AUTHORS: _authors_text()}),
			&"LabelCaptionHint")
	if not str(entry["text"]).is_empty():
		var button: ConsoleButton = ConsoleButton.new()
		button.list_row = true
		button.label_key = KEY_VIEW_LICENCE
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var id: String = str(entry["id"])
		button.pressed.connect(show_licence.bind(id))
		lines.add_child(button)
		# After `_ready`, which names the button after its label.
		button.accessibility_name = tr(KEY_A11Y_LICENCE).format(
			{PLACEHOLDER_NAME: str(entry["name"])})
		_licence_buttons[id] = button


static func _caption(box: Control, text: String, variation: StringName) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	box.add_child(label)


## §11.5: the authors of the game-icons that ship, by name, sorted.
func _authors_text() -> String:
	var folders: Array[String] = []
	folders.assign(CreditsData.icons_by_author(CreditsData.used_icon_paths()).keys())
	return SEPARATOR_LIST.join(CreditsData.author_names(_data, folders))


# ------------------------------------------------------------ the licences


## §11.2: the engine's notice and licence, then each third-party component
## with its copyright lines and licence id, then every licence text by name.
func _fill_engine() -> void:
	_block(tr(KEY_ENGINE_NOTICE))
	_block(Engine.get_license_text())
	_heading(tr(KEY_ENGINE_COMPONENTS))
	for info: Dictionary in Engine.get_copyright_info():
		var lines: PackedStringArray = [str(info.get("name", ""))]
		for part: Dictionary in info.get("parts", []):
			for holder: Variant in part.get("copyright", []):
				lines.append(COPYRIGHT_MARK + str(holder))
			lines.append(str(part.get("license", "")))
		_block("\n".join(lines))
	var licences: Dictionary = Engine.get_license_info()
	for licence: Variant in licences:
		_block("%s\n\n%s" % [str(licence), str(licences[licence])])


## §11.2: the icons used, author by author, then the notice and the legal code.
func _fill_game_icons() -> void:
	_heading(tr(KEY_ICONS_BY_AUTHOR))
	var by_author: Dictionary[String, Array] = CreditsData.icons_by_author(
		CreditsData.used_icon_paths())
	var authors: Dictionary = _data.get("authors", {})
	var rows: Array[Array] = []
	for folder: String in by_author:
		var author: Dictionary = authors.get(folder, {})
		rows.append([str(author.get("name", folder)), str(author.get("url", "")), folder])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	for row: Array in rows:
		var lines: PackedStringArray = [str(row[0])]
		if not str(row[1]).is_empty():
			lines.append(str(row[1]))
		var icons: PackedStringArray = []
		for icon: Variant in by_author[str(row[2])]:
			icons.append(str(icon))
		lines.append(SEPARATOR_LIST.join(icons))
		_block("\n".join(lines))
	_block(_read(GAME_ICONS_LICENCE))
	_block(_read(CC_BY_LEGAL_CODE))


static func _read(file: String) -> String:
	return FileAccess.get_file_as_string(file).strip_edges() if FileAccess.file_exists(file) \
		else file


## One block of licence text: a file, a component, an author list — so that no
## single label holds the whole engine's notices.
func _block(text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaptionHint"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_licence_blocks.add_child(label)


func _heading(text: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelHeading"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_licence_blocks.add_child(label)


func _entry(id: String) -> Dictionary:
	for section: Variant in _data.get("sections", []):
		for entry: Variant in (section as Dictionary).get("entries", []):
			if str((entry as Dictionary).get("id", "")) == id:
				return entry
	return {}


static func _clear(box: Control) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------- layout


## As tall as the window allows, like the Codex, so the two pages do not jump.
func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	_panel.custom_minimum_size.y = maxf(view.y - float(UiTokens.SPACE_6) * 2.0, 0.0)
