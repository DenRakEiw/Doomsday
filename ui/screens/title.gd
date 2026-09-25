extends Control
## The title screen (spec `screens-full.md` §3): the name, the ways in, and a
## globe lit by the last run.
##
## Scene-specific, so no `class_name`.

const KEY_NAME: String = "UI_TITLE_NAME"
const KEY_TAGLINE: String = "UI_TITLE_TAGLINE"
const KEY_CONTINUE_DAY: String = "UI_TITLE_CONTINUE_DAY"
const KEY_LOAD_FAILED: String = "UI_TITLE_LOAD_FAILED"
const KEY_VERSION: String = "UI_TITLE_VERSION"
## accessibility.md §5.1: `F1` and the pad's Back.
const ACTION_HELP: StringName = &"game_help"
## accessibility.md §5.3: the key list, over the settings.
const CONTROLS_SCENE: PackedScene = preload("res://ui/modals/controls.tscn")
const PLACEHOLDER_DAY: String = "day"
const PLACEHOLDER_VERSION: String = "version"
const SETTING_VERSION: String = "application/config/version"
## §7.1: no window to quit on a phone or in a browser.
const FEATURE_MOBILE: String = "mobile"
const FEATURE_WEB: String = "web"

## §3: the column is at most 420 wide and stands `GUTTER` × 3 from the left
## edge (the frame gives one gutter, the indent the other two). The globe's
## diameter is min(height × 0.8, width × 0.55); in compact it is the width less
## two gutters, at most 45 % of the height.
const COLUMN_MAX_WIDTH: float = 420.0
const INDENT_GUTTERS: float = 2.0
const GLOBE_HEIGHT_SHARE: float = 0.8
const GLOBE_WIDTH_SHARE: float = 0.55
const GLOBE_COMPACT_HEIGHT_SHARE: float = 0.45

@onready var _layout: BoxContainer = %Layout
@onready var _side: Control = %Side
@onready var _indent: Control = %Indent
@onready var _column: Control = %Column
@onready var _spacer: Control = %Spacer
@onready var _name_label: Label = %TitleName
@onready var _tagline: Label = %Tagline
@onready var _new_run: ConsoleButton = %NewRunButton
@onready var _continue: ConsoleButton = %ContinueButton
@onready var _continue_day: Label = %ContinueDay
@onready var _codex_button: ConsoleButton = %CodexButton
@onready var _statistics_button: ConsoleButton = %StatisticsButton
@onready var _settings: ConsoleButton = %SettingsButton
@onready var _credits_button: ConsoleButton = %CreditsButton
@onready var _quit: ConsoleButton = %QuitButton
@onready var _failure: Label = %TitleFailure
@onready var _globe_box: Control = %GlobeBox
@onready var _globe: Globe = %Globe
@onready var _version: Label = %VersionLabel
@onready var _buttons: Control = %Buttons
@onready var _corner: Control = $Corner
@onready var _settings_menu: Control = %TitleSettings
@onready var _codex: Control = %Codex
@onready var _statistics: Control = %Statistics
@onready var _credits: Control = %Credits
@onready var _host: ModalHost = $TitleHost

## accessibility.md §3.3: the title says its name and tagline once per launch.
static var _introduced: bool = false

var _controls: Control = null


func _ready() -> void:
	# §2: the boot is seen once the title shows.
	ProfileManager.mark_boot_seen()
	# A run that ended in the Open phase left its palette on (m3-screens §6.2);
	# outside a run the console is cold again, backdrop and globe included.
	if UiTokens.variant != UiTokens.VARIANT_COLD:
		UiTokens.variant = UiTokens.VARIANT_COLD
		EventBus.theme_variant_changed.emit(UiTokens.VARIANT_COLD)
	_new_run.pressed.connect(_on_new_run_pressed)
	_continue.pressed.connect(ScreenRouter.continue_run)
	_codex_button.pressed.connect(_open_modal.bind(_codex))
	_statistics_button.pressed.connect(_open_modal.bind(_statistics))
	_settings.pressed.connect(_on_settings_pressed)
	# icons.md §11.1: after Settings, before Quit; not in the pause menu.
	_credits_button.pressed.connect(_open_modal.bind(_credits))
	_quit.pressed.connect(_on_quit_pressed)
	ScreenRouter.load_failed.connect(_on_load_failed)
	for modal: Control in [_settings_menu, _codex, _statistics, _credits]:
		modal.connect(&"closed", _host.close)
	_statistics.connect(&"replay_requested", _on_replay_requested)
	_controls = CONTROLS_SCENE.instantiate() as Control
	_host.add_child(_controls)
	_controls.connect(&"closed", _host.close)
	_settings_menu.connect(&"controls_requested", _open_controls)
	_quit.visible = not (OS.has_feature(FEATURE_MOBILE) or OS.has_feature(FEATURE_WEB))
	_spacer.custom_minimum_size.y = float(UiTokens.SPACE_6)
	_indent.custom_minimum_size.x = float(UiTokens.GUTTER) * INDENT_GUTTERS
	get_viewport().size_changed.connect(_fit)
	# The column's height depends on the text scale and the language.
	_side.minimum_size_changed.connect(_fit)
	_refresh_strings()
	_refresh_continue()
	_show_last_run()
	_fit()
	_introduce()


## §3.3: the name and the tagline, spoken once — the title comes back after every
## run, and a reader need not hear it each time.
func _introduce() -> void:
	var live: LiveRegion = LiveRegion.new()
	live.name = "TitleLive"
	add_child(live)
	if _introduced or not LiveRegion.is_reader_active():
		return
	_introduced = true
	live.say(ModalHost.dialog_line(_name_label.text, _tagline.text))


## accessibility.md §5.3: over the settings, which it goes back to.
func _open_controls() -> void:
	_controls.call(&"open")
	_host.open_over(_controls)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		_refresh_continue()


## §3: Escape does nothing on the title — there is nothing to go back to.
func on_escape() -> void:
	pass


## first-run.md §6.7: `F1` opens the Codex on *How to play*, and closes it again.
## An action since S6.8 (accessibility.md §5.1): a remapped key, or Back on a pad.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_HELP):
		return
	get_viewport().set_input_as_handled()
	if _host.current() == _codex:
		_host.close()
	elif not _host.is_open():
		_open_modal(_codex)


## The primary button, which is where focus starts (§3).
func primary_button() -> ConsoleButton:
	return _continue if _continue.visible else _new_run


func _refresh_strings() -> void:
	_name_label.text = tr(KEY_NAME)
	_tagline.text = tr(KEY_TAGLINE)
	_version.text = tr(KEY_VERSION).format(
		{PLACEHOLDER_VERSION: str(ProjectSettings.get_setting(SETTING_VERSION, ""))})


## §3: Continue is the primary when there is a run to continue, and says which
## day it would put the player back on — without loading the run. Without one,
## New run is the primary.
func _refresh_continue() -> void:
	var day: int = SaveManager.peek_day(SaveManager.AUTOSAVE)
	_continue.visible = SaveManager.has_slot(SaveManager.AUTOSAVE)
	_continue_day.visible = _continue.visible and day >= 0
	_new_run.primary = not _continue.visible
	if _continue_day.visible:
		_continue_day.text = tr(KEY_CONTINUE_DAY).format(
			{PLACEHOLDER_DAY: Format.number(float(day), Format.Kind.DAYS)})
	primary_button().grab_focus.call_deferred()


## §3.1: the globe lights the regions the last run reached and rests on its origin.
func _show_last_run() -> void:
	var entry: Dictionary = {} if ProfileManager.history.is_empty() \
		else ProfileManager.history[0]
	_globe.show_run(entry, Game.content())


## §3: the column beside the globe at full width; below it, globe on top.
func _fit() -> void:
	var view: Vector2 = get_viewport_rect().size
	var compact: bool = view.x < float(UiTokens.COMPACT_WIDTH)
	_layout.vertical = compact
	_layout.move_child(_globe_box, 0 if compact else 1)
	_indent.visible = not compact
	_side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_FILL
	var gutter: float = float(UiTokens.GUTTER)
	var diameter: float = 0.0
	if compact:
		_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_column.custom_minimum_size.x = 0.0
		# The column comes first: at 150 % text on a phone it needs more than
		# the 55 % the globe leaves, so the globe takes what is left over.
		var column_height: float = _side.get_combined_minimum_size().y
		diameter = minf(minf(view.x - gutter * 2.0, view.y * GLOBE_COMPACT_HEIGHT_SHARE),
			view.y - column_height - gutter * 3.0)
		diameter = maxf(diameter, 0.0)
	else:
		_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_column.custom_minimum_size.x = COLUMN_MAX_WIDTH
		diameter = minf(view.y * GLOBE_HEIGHT_SHARE, view.x * GLOBE_WIDTH_SHARE)
	_globe.custom_minimum_size = Vector2(diameter, diameter)
	_place_version(compact)


## §3's G5 (1/3) amendment: in the corner the caption covered the last button
## of a narrow window, so in compact it is the column's last row instead — in
## the buttons' stack, `SPACE_2` under Quit, right-aligned. The same label moves;
## its text is set once.
func _place_version(compact: bool) -> void:
	var home: Control = _buttons if compact else _corner
	if _version.get_parent() != home:
		_version.reparent(home, false)
	home.move_child(_version, home.get_child_count() - 1)
	_version.size_flags_horizontal = Control.SIZE_SHRINK_END if compact \
			else Control.SIZE_FILL
	_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## The version caption, for the tests.
func version_label() -> Label:
	return _version


func _on_new_run_pressed() -> void:
	ScreenRouter.show_setup()


## The settings the title shows are the pause menu's, so there is one of them
## (§7.3). The host gives it the scrim and takes `Escape`.
func _on_settings_pressed() -> void:
	_settings_menu.call(&"open_settings_only")
	_host.open(_settings_menu)


func _open_modal(modal: Control) -> void:
	modal.call(&"open")
	_host.open(modal)


## §6.2: *Play this seed again* — the setup opens on that run's build and seed.
func _on_replay_requested(seed_value: int, setup: RunSetup) -> void:
	_host.close()
	ScreenRouter.show_setup(seed_value, setup)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_load_failed(reason: String) -> void:
	_failure.visible = true
	_failure.text = tr(KEY_LOAD_FAILED).format({"reason": tr(reason.to_upper())})
	_refresh_continue()
