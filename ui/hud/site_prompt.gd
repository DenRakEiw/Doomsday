extends PanelContainer
## "Tap an outlined region" (`loop-mechanics.md` §16.1).
##
## A strip under the top bar while the map is being asked **where** — the
## origin at the start of a run, a deploying node's site, and from S4.2 an
## ability's target. It says what is being placed and offers the way out; the
## region panel is where the answer is given.
##
## It replaces `origin_prompt.tscn` of S3.4 in the same slot: the origin became
## one `SiteRequest` among three.
##
## Scene-specific, so no `class_name`.

const KEY_ORIGIN_PROMPT: String = "UI_ORIGIN_PROMPT"
const KEY_ORIGIN_DETAIL: String = "UI_ORIGIN_PROMPT_DETAIL"
const KEY_DETAIL: String = "UI_SITE_PROMPT_DETAIL"
const KEY_CANCEL: String = "UI_SITE_CANCEL"
const PLACEHOLDER_NAME: String = "name"
## §7.2: an island in the full layout, the whole width on a phone.
const MAX_WIDTH: float = 640.0

@onready var _prompt: Label = %SitePromptTitle
@onready var _detail: Label = %SitePromptDetail
@onready var _cancel: ConsoleButton = %SiteCancel


func _ready() -> void:
	_cancel.pressed.connect(_on_cancel_pressed)
	_cancel.label_key = KEY_CANCEL
	EventBus.run_started.connect(_on_run_started)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.site_select_changed.connect(_on_site_select_changed)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## The compact layout gives the strip the whole width; the full one centres it.
func set_compact(compact: bool) -> void:
	custom_minimum_size.x = 0.0 if compact else MAX_WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER


## Visible exactly while there is a request. The origin one is entered by the
## session on `run_started`, so the strip never has to know about the origin.
func refresh() -> void:
	var request: SiteRequest = Game.site_request
	visible = request != null
	if request == null:
		return
	if request.kind == SiteRequest.KIND_ORIGIN:
		_prompt.text = tr(KEY_ORIGIN_PROMPT)
		_detail.text = tr(KEY_ORIGIN_DETAIL)
	else:
		_prompt.text = tr(request.title_key).format({PLACEHOLDER_NAME: tr(request.name_key)})
		_detail.text = tr(KEY_DETAIL)
	_cancel.visible = request.can_cancel()


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()


func _on_site_select_changed(_active: bool) -> void:
	refresh()


func _on_cancel_pressed() -> void:
	Game.site_cancel()
