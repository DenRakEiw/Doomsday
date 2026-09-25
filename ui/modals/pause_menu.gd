extends Control
## Pause, save, load, settings, quit (spec m3-screens.md §7.3).
##
## The title opens the same scene with `settings_only`, so there is one settings
## screen in the game and not two that drift apart.
##
## Scene-specific, so no `class_name`.

## The menu wants to be closed (its own button, `Escape`, or Resume).
signal closed
## Quit was confirmed: the router takes it from here.
signal quit_requested
## accessibility.md §5.3: the *Controls* modal, over this one.
signal controls_requested

const KEY_TITLE: String = "UI_PAUSE_TITLE"
const KEY_SEED: String = "UI_PAUSE_SEED"
const KEY_DAY: String = "UI_PAUSE_DAY"
const KEY_SAVE: String = "UI_PAUSE_SAVE"
const KEY_LOAD: String = "UI_PAUSE_LOAD"
const KEY_SLOT: String = "UI_PAUSE_SLOT"
const KEY_SLOT_DAY: String = "UI_PAUSE_SLOT_DAY"
const KEY_SLOT_EMPTY: String = "UI_PAUSE_SLOT_EMPTY"
const KEY_SAVE_FAILED: String = "UI_PAUSE_SAVE_FAILED"
const KEY_LOAD_FAILED: String = "UI_PAUSE_LOAD_FAILED"
const KEY_LOAD_CONFIRM: String = "UI_PAUSE_LOAD_CONFIRM"
const KEY_QUIT_CONFIRM: String = "UI_PAUSE_QUIT_CONFIRM"
const KEY_SETTINGS_TITLE: String = "UI_SETTINGS_TITLE"
const KEY_LOCALE: String = "UI_SETTINGS_LOCALE"
const KEY_LOCALE_EN: String = "UI_SETTINGS_LOCALE_EN"
const KEY_LOCALE_DE: String = "UI_SETTINGS_LOCALE_DE"
const KEY_REDUCED_MOTION: String = "UI_SETTINGS_REDUCED_MOTION"
const KEY_SCREEN_EFFECTS: String = "UI_SETTINGS_SCREEN_EFFECTS"
const KEY_FX_SUBTLE: String = "UI_SETTINGS_FX_SUBTLE"
const KEY_FX_FULL: String = "UI_SETTINGS_FX_FULL"
const KEY_TREE_PAUSES: String = "UI_SETTINGS_TREE_PAUSES"
const KEY_TUTORIAL: String = "UI_SETTINGS_TUTORIAL"
## first-run.md §6.1: directly after *Introduction*.
const KEY_HINTS: String = "UI_SETTINGS_HINTS"
const KEY_TEXT_SCALE: String = "UI_SETTINGS_TEXT_SCALE"
const KEY_BOOT: String = "UI_SETTINGS_BOOT"
const KEY_BOOT_FIRST: String = "UI_SETTINGS_BOOT_FIRST"
const KEY_BOOT_ALWAYS: String = "UI_SETTINGS_BOOT_ALWAYS"
## audio.md §3.3: the sound rows, after *Text size* and before *Introduction*.
const KEY_VOLUME_MASTER: String = "UI_SETTINGS_VOLUME_MASTER"
const KEY_VOLUME_MUSIC: String = "UI_SETTINGS_VOLUME_MUSIC"
const KEY_VOLUME_AMBIENCE: String = "UI_SETTINGS_VOLUME_AMBIENCE"
const KEY_VOLUME_INTERFACE: String = "UI_SETTINGS_VOLUME_INTERFACE"
const KEY_VOLUME_ALERTS: String = "UI_SETTINGS_VOLUME_ALERTS"
const KEY_SOUND_CAPTIONS: String = "UI_SETTINGS_SOUND_CAPTIONS"
const KEY_AUDIO_BACKGROUND: String = "UI_SETTINGS_AUDIO_BACKGROUND"
## accessibility.md §3.4: directly after *Background audio*.
const KEY_READ_HEADLINES: String = "UI_SETTINGS_READ_HEADLINES"
## accessibility.md §5.3: the last row before *Reset progress*, not on a phone.
const KEY_CONTROLS: String = "UI_SETTINGS_CONTROLS"
const KEY_CONTROLS_OPEN: String = "UI_SETTINGS_CONTROLS_OPEN"
## §3.2: a settings button is named by its row and its value.
const KEY_A11Y_LABEL_VALUE: String = "UI_A11Y_LABEL_VALUE"
## Row label → the bus its button cycles.
const VOLUME_ROWS: Dictionary[String, StringName] = {
	KEY_VOLUME_MASTER: &"master",
	KEY_VOLUME_MUSIC: &"music",
	KEY_VOLUME_AMBIENCE: &"ambience",
	KEY_VOLUME_INTERFACE: &"interface",
	KEY_VOLUME_ALERTS: &"alerts",
}
const KEY_RESET_PROFILE: String = "UI_SETTINGS_RESET_PROFILE"
const KEY_RESET_CONFIRM: String = "UI_SETTINGS_RESET_CONFIRM"
## release.md §10: where a player finds the log and the saves — the title's
## settings only, and only where there is a folder to open.
const KEY_DATA_FOLDER: String = "UI_SETTINGS_DATA_FOLDER"
## benchmark.md §16.6: the online leaderboard's switch — the title's settings
## only, after *Open data folder*, on every platform.
const KEY_BENCH_ONLINE: String = "UI_SETTINGS_BENCH_ONLINE"
const USER_DIR: String = "user://"
## The rows in the order they are built. polish-visuals.md §5.1 put *Screen
## effects* directly after *Reduced motion*; screens-full.md §6.3's boot row is
## the title's only.
const INDEX_LOCALE: int = 0
const INDEX_REDUCED_MOTION: int = 1
const INDEX_SCREEN_EFFECTS: int = 2
const INDEX_TREE_PAUSES: int = 3
const INDEX_TEXT_SCALE: int = 4
const INDEX_VOLUME_MASTER: int = 5
const INDEX_VOLUME_MUSIC: int = 6
const INDEX_VOLUME_AMBIENCE: int = 7
const INDEX_VOLUME_INTERFACE: int = 8
const INDEX_VOLUME_ALERTS: int = 9
const INDEX_SOUND_CAPTIONS: int = 10
const INDEX_AUDIO_BACKGROUND: int = 11
const INDEX_READ_HEADLINES: int = 12
const INDEX_TUTORIAL: int = 13
const INDEX_HINTS: int = 14
const INDEX_BOOT: int = 15
## The rows' labels in the order of the indices above.
const SETTING_KEYS: Array[String] = [KEY_LOCALE, KEY_REDUCED_MOTION, KEY_SCREEN_EFFECTS,
	KEY_TREE_PAUSES, KEY_TEXT_SCALE, KEY_VOLUME_MASTER, KEY_VOLUME_MUSIC, KEY_VOLUME_AMBIENCE,
	KEY_VOLUME_INTERFACE, KEY_VOLUME_ALERTS, KEY_SOUND_CAPTIONS, KEY_AUDIO_BACKGROUND,
	KEY_READ_HEADLINES, KEY_TUTORIAL, KEY_HINTS, KEY_BOOT]
## A volume button plays no click: `Audio` previews the bus instead (§3.3).
const META_AUDIO_CUE: StringName = &"audio_cue"
const FEATURE_WEB: String = "web"
const FEATURE_MOBILE: String = "mobile"
const KEY_ON: String = "UI_SETTINGS_ON"
const KEY_OFF: String = "UI_SETTINGS_OFF"

const PLACEHOLDER_SEED: String = "seed"
const PLACEHOLDER_DAY: String = "day"
const PLACEHOLDER_SLOT: String = "n"
const PLACEHOLDER_REASON: String = "reason"

## The three manual slots of §7.3.
const SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]

@onready var _panel: PanelContainer = %PausePanel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _body: VBoxContainer = %Body
@onready var _title: Label = %PauseTitle
@onready var _caption: Label = %PauseCaption
@onready var _resume: ConsoleButton = %ResumeButton
@onready var _help: ConsoleButton = %HelpButton
@onready var _save_block: Control = %SaveBlock
@onready var _save_title: CapsLabel = %SaveTitle
@onready var _save_row: Container = %SaveRow
@onready var _load_block: Control = %LoadBlock
@onready var _load_title: CapsLabel = %LoadTitle
@onready var _load_row: Container = %LoadRow
@onready var _failure: Label = %PauseFailure
@onready var _settings_title: CapsLabel = %SettingsTitle
@onready var _settings_rows: VBoxContainer = %SettingsRows
@onready var _quit: ConsoleButton = %QuitButton
@onready var _confirm: ConfirmModal = %PauseConfirm

## §7.3: the title opens the settings alone.
var settings_only: bool = false

## Slot → its two buttons and its caption.
var _save_buttons: Array[ConsoleButton] = []
var _load_buttons: Array[ConsoleButton] = []
var _slot_captions: Array[Label] = []
var _setting_buttons: Array[ConsoleButton] = []
## screens-full.md §6.3: the boot row and *Reset progress*, on the title only.
var _title_rows: Array[Control] = []
var _reset: ConsoleButton = null
var _data_folder: ConsoleButton = null
var _bench_online: ConsoleButton = null
## accessibility.md §5.3: *Change* on the *Controls* row.
var _controls: ConsoleButton = null


func _ready() -> void:
	# accessibility.md §4.2: the focus ring is neither clipped nor scrolled away.
	A11y.focus_scroll(_scroll)
	_resume.pressed.connect(_on_resume_pressed)
	_help.pressed.connect(_on_help_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_build_slots()
	_build_settings()
	_refresh_strings()
	# The same fit as the results (G3): a `ScrollContainer` has no height of its
	# own, and without one the menu opened as an empty strip (S4.9 screenshots).
	_body.minimum_size_changed.connect(_fit_scroll)
	get_viewport().size_changed.connect(_fit_scroll)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		refresh()


## Opens the whole menu.
func open_menu() -> void:
	settings_only = false
	_apply_mode()
	refresh()
	_fit_scroll()
	_resume.grab_focus.call_deferred()


## Opens only the settings section, which is what the title screen shows (§7.3).
func open_settings_only() -> void:
	settings_only = true
	_apply_mode()
	refresh()
	visible = true
	_fit_scroll()
	_setting_buttons[0].grab_focus.call_deferred()


## accessibility.md §4.4 item 5: `Escape` in a confirm answers *Cancel* and
## leaves the menu open; only otherwise does it close the menu.
func on_escape() -> void:
	if _confirm.visible:
		_confirm.on_escape()
		return
	closed.emit()


## Re-reads the run and the save slots.
func refresh() -> void:
	_failure.visible = false
	if not settings_only and Game.sim != null:
		_caption.text = "%s · %s" % [
			tr(KEY_SEED).format({PLACEHOLDER_SEED: Game.run_seed()}),
			tr(KEY_DAY).format({PLACEHOLDER_DAY:
				Format.number(float(Game.sim.world.day), Format.Kind.DAYS)}),
		]
	for i: int in SLOTS.size():
		var day: int = SaveManager.peek_day(SLOTS[i])
		_slot_captions[i].text = tr(KEY_SLOT_EMPTY) if day < 0 \
			else tr(KEY_SLOT_DAY).format({PLACEHOLDER_DAY:
				Format.number(float(day), Format.Kind.DAYS)})
		_load_buttons[i].disabled = day < 0
		# accessibility.md §3.3: `{slot}: {caption}` — the slot's day is part of it.
		var slot: String = tr(KEY_SLOT).format({PLACEHOLDER_SLOT: i + 1})
		_save_buttons[i].accessibility_name = A11y.label_value(slot, _slot_captions[i].text)
		_load_buttons[i].accessibility_name = A11y.label_value(slot, _slot_captions[i].text)
	_refresh_settings()


func _apply_mode() -> void:
	_caption.visible = not settings_only
	_resume.visible = not settings_only
	_help.visible = not settings_only
	# benchmark.md §12.4: a watched run has nothing to save, and a load would
	# drop the replay — *Quit to title* is the way out.
	_save_block.visible = not settings_only and not Game.is_spectating()
	_load_block.visible = not settings_only and not Game.is_spectating()
	_quit.visible = not settings_only
	for row: Control in _title_rows:
		row.visible = settings_only
	_data_folder.visible = settings_only and has_data_folder()
	# From the title the modal is titled Settings already; the section caption
	# under it said the same word again (S4.9).
	_settings_title.visible = not settings_only
	_title.text = tr(KEY_SETTINGS_TITLE if settings_only else KEY_TITLE)


func _refresh_strings() -> void:
	_apply_mode()
	_save_title.label_key = KEY_SAVE
	_load_title.label_key = KEY_LOAD
	_settings_title.label_key = KEY_SETTINGS_TITLE
	for i: int in SLOTS.size():
		var text: String = tr(KEY_SLOT).format({PLACEHOLDER_SLOT: i + 1})
		_save_buttons[i].text = Format.caps(text)
		_load_buttons[i].text = Format.caps(text)


# --------------------------------------------------------------- the rows


func _build_slots() -> void:
	for i: int in SLOTS.size():
		_save_buttons.append(_slot_button(_save_row, _on_save_pressed.bind(i), true))
		_load_buttons.append(_slot_button(_load_row, _on_load_pressed.bind(i), false))


## A slot is a button with a caption under it, so the two rows line up.
func _slot_button(into: Container, action: Callable, with_caption: bool) -> ConsoleButton:
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"StackTight"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button: ConsoleButton = ConsoleButton.new()
	button.pressed.connect(action)
	column.add_child(button)
	if with_caption:
		var caption: Label = Label.new()
		caption.theme_type_variation = &"LabelCaption"
		column.add_child(caption)
		_slot_captions.append(caption)
	into.add_child(column)
	return button


## §7.3 item 5: the settings, each a label and a button that says the state. The
## text scale of UI.md §5 came in S4.9, the introduction (first-run.md §3.1) in
## S4.11, and so they are the last rows.
func _build_settings() -> void:
	for key: String in SETTING_KEYS:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"Row"
		var label: Label = Label.new()
		label.theme_type_variation = &"LabelCaption"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# A long German setting would hold the menu wider than a phone (S4.9).
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = tr(key)
		label.set_meta(&"key", key)
		row.add_child(label)
		var button: ConsoleButton = ConsoleButton.new()
		if VOLUME_ROWS.has(key):
			button.set_meta(META_AUDIO_CUE, &"")
		button.pressed.connect(_on_setting_pressed.bind(_setting_buttons.size()))
		row.add_child(button)
		_setting_buttons.append(button)
		_settings_rows.add_child(row)
		if key == KEY_BOOT:
			_title_rows.append(row)
		# §3.3: a browser or a phone has no window to lose focus to.
		if key == KEY_AUDIO_BACKGROUND:
			row.visible = not (OS.has_feature(FEATURE_WEB) or OS.has_feature(FEATURE_MOBILE))
	_build_controls_row()
	_data_folder = ConsoleButton.new()
	_data_folder.label_key = KEY_DATA_FOLDER
	_data_folder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_data_folder.pressed.connect(_on_data_folder_pressed)
	_settings_rows.add_child(_data_folder)
	_build_bench_online_row()
	# §6.3: progress is not a run — the autosave and the slots stay.
	_reset = ConsoleButton.new()
	_reset.label_key = KEY_RESET_PROFILE
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reset.pressed.connect(_on_reset_pressed)
	_reset.alert = true
	_settings_rows.add_child(_reset)
	_title_rows.append(_reset)


func _refresh_settings() -> void:
	for row: Node in _settings_rows.get_children():
		if not row is HBoxContainer:
			continue
		var label: Label = (row as Container).get_child(0) as Label
		label.text = tr(str(label.get_meta(&"key")))
	for i: int in _setting_buttons.size():
		var value: String = setting_value(i)
		_setting_buttons[i].text = Format.caps(value)
		# accessibility.md §3.2 item 1: *On* alone says nothing; the row's label
		# does, and the name is not shouted.
		_setting_buttons[i].accessibility_name = tr(KEY_A11Y_LABEL_VALUE).format({
			"label": tr(SETTING_KEYS[i]), "value": value})
	if _controls != null:
		_controls.accessibility_name = tr(KEY_A11Y_LABEL_VALUE).format({
			"label": tr(KEY_CONTROLS), "value": tr(KEY_CONTROLS_OPEN)})
	if _bench_online != null:
		var online: String = _on_off(Settings.bench_online)
		_bench_online.text = Format.caps(online)
		_bench_online.accessibility_name = tr(KEY_A11Y_LABEL_VALUE).format({
			"label": tr(KEY_BENCH_ONLINE), "value": online})


## The words a settings button shows for row `index`, before they are uppercased.
func setting_value(index: int) -> String:
	var key: String = SETTING_KEYS[index]
	if VOLUME_ROWS.has(key):
		# audio.md §3.3: a volume as a percentage, or *Off* at 0.
		var volume: float = Audio.volume(VOLUME_ROWS[key])
		return tr(KEY_OFF) if volume <= 0.0 else Format.number(volume, Format.Kind.PERCENT)
	match index:
		INDEX_LOCALE:
			return tr(KEY_LOCALE_DE if Settings.locale == "de" else KEY_LOCALE_EN)
		INDEX_REDUCED_MOTION:
			return _on_off(Settings.reduced_motion)
		INDEX_SCREEN_EFFECTS:
			return tr(screen_effects_key(Settings.screen_effects))
		INDEX_TREE_PAUSES:
			return _on_off(Settings.tree_pauses)
		INDEX_TEXT_SCALE:
			return Format.number(Settings.text_scale, Format.Kind.PERCENT)
		INDEX_SOUND_CAPTIONS:
			return _on_off(Settings.sound_captions)
		INDEX_AUDIO_BACKGROUND:
			return _on_off(Settings.audio_background)
		INDEX_READ_HEADLINES:
			return _on_off(Settings.announce_headlines)
		INDEX_TUTORIAL:
			return _on_off(Settings.tutorial)
		INDEX_HINTS:
			return _on_off(Settings.hints)
	return tr(KEY_BOOT_ALWAYS if Settings.boot_always else KEY_BOOT_FIRST)


func _on_off(value: bool) -> String:
	return tr(KEY_ON if value else KEY_OFF)


## §5.3: a label and *Change*, which asks for the *Controls* modal. A phone has
## no keys to change.
func _build_controls_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"Row"
	row.name = "ControlsRow"
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr(KEY_CONTROLS)
	label.set_meta(&"key", KEY_CONTROLS)
	row.add_child(label)
	_controls = ConsoleButton.new()
	_controls.label_key = KEY_CONTROLS_OPEN
	_controls.pressed.connect(controls_requested.emit)
	row.add_child(_controls)
	row.visible = not OS.has_feature(FEATURE_MOBILE)
	_settings_rows.add_child(row)


## A label and an On/Off button, like the rows above it; a title row.
func _build_bench_online_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"Row"
	row.name = "BenchOnlineRow"
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr(KEY_BENCH_ONLINE)
	label.set_meta(&"key", KEY_BENCH_ONLINE)
	row.add_child(label)
	_bench_online = ConsoleButton.new()
	_bench_online.pressed.connect(_on_bench_online_pressed)
	row.add_child(_bench_online)
	_settings_rows.add_child(row)
	_title_rows.append(row)


## The *Online leaderboard* button, for the tests.
func bench_online_button() -> ConsoleButton:
	return _bench_online


func _on_bench_online_pressed() -> void:
	Settings.set_bench_online(not Settings.bench_online)
	_refresh_settings()


## The *Change* button, for the tests and for the focus to come back to.
func controls_button() -> ConsoleButton:
	return _controls


## §5.1: the button's word for an intensity — the nearest of the three steps.
static func screen_effects_key(intensity: float) -> String:
	if intensity <= 0.0:
		return KEY_OFF
	var subtle: float = UiTokens.FX_INTENSITIES[1]
	var full: float = UiTokens.FX_INTENSITIES[UiTokens.FX_INTENSITIES.size() - 1]
	return KEY_FX_SUBTLE if absf(intensity - subtle) < absf(intensity - full) else KEY_FX_FULL


# ------------------------------------------------------------------ actions


func _on_resume_pressed() -> void:
	closed.emit()


## first-run.md §6.7: the session's page, over the menu; closing it comes back here.
func _on_help_pressed() -> void:
	EventBus.help_requested.emit(HelpPages.page_for_context(HelpPages.CONTEXT_SESSION))


func _on_save_pressed(index: int) -> void:
	var reason: String = SaveManager.save(SLOTS[index])
	if reason.is_empty():
		# The same arrival the revealed blocks use — a save that worked says so
		# by the slot's caption changing under a button that just lit up.
		Reveal.play(_save_buttons[index])
		refresh()
		return
	_show_failure(KEY_SAVE_FAILED, reason)


func _on_load_pressed(index: int) -> void:
	if not await _confirm.ask(KEY_LOAD_CONFIRM):
		return
	var reason: String = SaveManager.load(SLOTS[index])
	if not reason.is_empty():
		_show_failure(KEY_LOAD_FAILED, reason)
		return
	closed.emit()


func _on_setting_pressed(index: int) -> void:
	var key: String = SETTING_KEYS[index]
	if VOLUME_ROWS.has(key):
		Audio.cycle_volume(VOLUME_ROWS[key])
		_refresh_settings()
		return
	match index:
		INDEX_LOCALE:
			Settings.toggle_locale()
		INDEX_REDUCED_MOTION:
			Settings.set_reduced_motion(not Settings.reduced_motion)
		INDEX_SCREEN_EFFECTS:
			Settings.cycle_screen_effects()
		INDEX_TREE_PAUSES:
			Settings.set_tree_pauses(not Settings.tree_pauses)
		INDEX_TEXT_SCALE:
			Settings.cycle_text_scale()
		INDEX_SOUND_CAPTIONS:
			Settings.set_sound_captions(not Settings.sound_captions)
		INDEX_AUDIO_BACKGROUND:
			Settings.set_audio_background(not Settings.audio_background)
		INDEX_READ_HEADLINES:
			Settings.set_announce_headlines(not Settings.announce_headlines)
		INDEX_TUTORIAL:
			Settings.set_tutorial(not Settings.tutorial)
		INDEX_HINTS:
			Settings.set_hints(not Settings.hints)
		_:
			Settings.set_boot_always(not Settings.boot_always)
	_refresh_settings()


## release.md §10: a phone and a browser have no folder a player could open.
static func has_data_folder() -> bool:
	return not (OS.has_feature(FEATURE_WEB) or OS.has_feature(FEATURE_MOBILE))


## The *Open data folder* button, for the tests.
func data_folder_button() -> ConsoleButton:
	return _data_folder


func _on_data_folder_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(USER_DIR))


func _on_reset_pressed() -> void:
	if await _confirm.ask(KEY_RESET_CONFIRM):
		ProfileManager.reset()


func _on_quit_pressed() -> void:
	if await _confirm.ask(KEY_QUIT_CONFIRM):
		quit_requested.emit()


func _show_failure(key: String, reason: String) -> void:
	_failure.visible = true
	_failure.text = tr(key).format({PLACEHOLDER_REASON: tr(reason.to_upper())})


## Fits the menu to the window. The scroll takes the body's height, capped at
## the window, so it scrolls only on a window too short for the menu — at 150 %
## text on a phone, say.
func _fit_scroll() -> void:
	# Three slot buttons with the desktop padding are wider than a phone's menu;
	# below the breakpoint they take the compact bar's padding (S4.9).
	var narrow: bool = get_viewport_rect().size.x < float(UiTokens.COMPACT_WIDTH)
	for button: ConsoleButton in _save_buttons + _load_buttons:
		button.compact = narrow
	var available: float = get_viewport_rect().size.y - float(UiTokens.SPACE_6) * 2.0
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y
		+ float(UiTokens.FOCUS_OUTSET) * 2.0,
		maxf(available, 0.0))
