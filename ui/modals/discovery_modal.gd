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
## `loop-mechanics.md` §16.7: the modal has the wire card's picture slot, with
## the id M6 drops its file under and the alert mark until then.
const ILLUSTRATION: String = "discovery"
const COMPACT_WIDTH: float = 1100.0

@onready var _title: Label = %DiscoveryTitle
@onready var _cause: Label = %DiscoveryCause
@onready var _body: Label = %DiscoveryBody
@onready var _day: Label = %DiscoveryDay
@onready var _continue: ConsoleButton = %ContinueButton
@onready var _containment: ConsoleButton = %ContainmentButton
@onready var _panel: PanelContainer = %DiscoveryPanel
@onready var _layout: BoxContainer = %Layout
@onready var _illustration: IllustrationSlot = %Illustration

var _cause_key: String = KEY_CAUSE_SCRUTINY
var _day_value: int = 0


func _ready() -> void:
	_illustration.show_illustration(ILLUSTRATION, Glyphs.Glyph.EVENT_COUNTER, &"ALERT")
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_continue.pressed.connect(dismissed.emit)
	_containment.pressed.connect(containment_requested.emit)
	_refresh_strings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


## The picture sits left of the text in the full layout and above it in the
## compact one, like the wire card's (§16.7).
func _apply_layout() -> void:
	var compact: bool = get_viewport_rect().size.x < COMPACT_WIDTH
	_layout.vertical = compact
	_illustration.compact = compact


## The picture slot, for the tests.
func illustration() -> IllustrationSlot:
	return _illustration


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
