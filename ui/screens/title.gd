extends Control
## The title screen (spec m3-screens.md §7.1) — a placeholder until D5.3 designs
## the real one. It knows four buttons and one save file.
##
## Scene-specific, so no `class_name`.

const KEY_NAME: String = "UI_TITLE_NAME"
const KEY_TAGLINE: String = "UI_TITLE_TAGLINE"
const KEY_CONTINUE_DAY: String = "UI_TITLE_CONTINUE_DAY"
const KEY_LOAD_FAILED: String = "UI_TITLE_LOAD_FAILED"
const KEY_VERSION: String = "UI_TITLE_VERSION"
const PLACEHOLDER_DAY: String = "day"
const PLACEHOLDER_VERSION: String = "version"
const SETTING_VERSION: String = "application/config/version"
## §7.1: no window to quit on a phone or in a browser.
const FEATURE_MOBILE: String = "mobile"
const FEATURE_WEB: String = "web"

@onready var _name_label: Label = %TitleName
@onready var _tagline: Label = %Tagline
@onready var _new_run: ConsoleButton = %NewRunButton
@onready var _continue: ConsoleButton = %ContinueButton
@onready var _continue_day: Label = %ContinueDay
@onready var _settings: ConsoleButton = %SettingsButton
@onready var _quit: ConsoleButton = %QuitButton
@onready var _failure: Label = %TitleFailure
@onready var _version: Label = %VersionLabel
@onready var _settings_menu: Control = %TitleSettings
@onready var _host: ModalHost = $TitleHost


func _ready() -> void:
	_new_run.pressed.connect(ScreenRouter.start_new_run)
	_continue.pressed.connect(ScreenRouter.continue_run)
	_settings.pressed.connect(_on_settings_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	ScreenRouter.load_failed.connect(_on_load_failed)
	_settings_menu.connect(&"closed", _host.close)
	_quit.visible = not (OS.has_feature(FEATURE_MOBILE) or OS.has_feature(FEATURE_WEB))
	_refresh_strings()
	_refresh_continue()
	_new_run.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()
		_refresh_continue()


func _refresh_strings() -> void:
	_name_label.text = tr(KEY_NAME)
	_tagline.text = tr(KEY_TAGLINE)
	_version.text = tr(KEY_VERSION).format(
		{PLACEHOLDER_VERSION: str(ProjectSettings.get_setting(SETTING_VERSION, ""))})


## §7.1: Continue is there when there is something to continue, and says which
## day it would put the player back on — without loading the run.
func _refresh_continue() -> void:
	var day: int = SaveManager.peek_day(SaveManager.AUTOSAVE)
	_continue.visible = SaveManager.has_slot(SaveManager.AUTOSAVE)
	_continue_day.visible = _continue.visible and day >= 0
	if _continue_day.visible:
		_continue_day.text = tr(KEY_CONTINUE_DAY).format(
			{PLACEHOLDER_DAY: Format.number(float(day), Format.Kind.DAYS)})


## The settings the title shows are the pause menu's, so there is one of them
## (§7.3). The host gives it the scrim and takes `Escape`.
func _on_settings_pressed() -> void:
	_settings_menu.call(&"open_settings_only")
	_host.open(_settings_menu)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_load_failed(reason: String) -> void:
	_failure.visible = true
	_failure.text = tr(KEY_LOAD_FAILED).format({"reason": tr(reason.to_upper())})
	_refresh_continue()
