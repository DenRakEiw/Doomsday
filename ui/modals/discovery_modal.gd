extends Control
## The moment they find you (spec m3-screens.md §5).
##
## One title, one sentence, one choice. Everything the world says about it is the
## ticker's job; this is the only thing that stops the game.
##
## Scene-specific, so no `class_name`.

## Continue was pressed, or `Escape`.
signal dismissed
## The primary button: close and open the containment panel.
signal containment_requested

const KEY_TITLE: String = "UI_DISCOVERY_TITLE"
const KEY_BODY: String = "UI_DISCOVERY_BODY"
const KEY_DAY: String = "UI_DISCOVERY_DAY"
const KEY_CAUSE_SCRUTINY: String = "UI_DISCOVERY_CAUSE_SCRUTINY"
const KEY_CAUSE_DEATHS: String = "UI_DISCOVERY_CAUSE_DEATHS"
const PLACEHOLDER_DAY: String = "day"

@onready var _title: Label = %DiscoveryTitle
@onready var _cause: Label = %DiscoveryCause
@onready var _body: Label = %DiscoveryBody
@onready var _day: Label = %DiscoveryDay
@onready var _continue: ConsoleButton = %ContinueButton
@onready var _containment: ConsoleButton = %ContainmentButton
@onready var _panel: PanelContainer = %DiscoveryPanel

var _cause_key: String = KEY_CAUSE_SCRUTINY
var _day_value: int = 0


func _ready() -> void:
	_panel.custom_minimum_size.x = float(UiTokens.MODAL_MAX_WIDTH)
	_continue.pressed.connect(dismissed.emit)
	_containment.pressed.connect(containment_requested.emit)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


## The cause is the `discovered` event's, the day the world's.
func show_discovery(cause: String, day: int) -> void:
	_cause_key = KEY_CAUSE_DEATHS if cause == SimEvent.CAUSE_DEATHS else KEY_CAUSE_SCRUTINY
	_day_value = day
	_refresh_strings()
	_containment.grab_focus.call_deferred()


## `Escape` is Continue (§5).
func on_escape() -> void:
	dismissed.emit()


func _refresh_strings() -> void:
	_title.text = tr(KEY_TITLE)
	_cause.text = tr(_cause_key)
	_body.text = tr(KEY_BODY)
	_day.text = tr(KEY_DAY).format(
		{PLACEHOLDER_DAY: Format.number(float(_day_value), Format.Kind.DAYS)})
