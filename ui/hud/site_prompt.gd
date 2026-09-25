extends PanelContainer
## "Tap an outlined region" (`loop-mechanics.md` §16.1, `first-run.md` §1–§2).
##
## A strip just above the bottom of the map while the map is being asked
## **where** — the origin at the start of a run, a deploying node's site, and an
## ability's target. It says what is being placed and offers the way out; the
## region panel is where the answer is given.
##
## It sits at the bottom since S4.11: at the top it covered Europe while the
## origin was being chosen. It folds away without cancelling the choice, and
## while a region is hovered it says whether that region will do and why not.
##
## Scene-specific, so no `class_name`.

const KEY_ORIGIN_PROMPT: String = "UI_ORIGIN_PROMPT"
const KEY_ORIGIN_DETAIL: String = "UI_ORIGIN_PROMPT_DETAIL"
const KEY_DETAIL: String = "UI_SITE_PROMPT_DETAIL"
const KEY_CANCEL: String = "UI_SITE_CANCEL"
const KEY_HOVER_OK: String = "UI_SITE_HOVER_OK"
## accessibility.md §4.5: the same line for the keyboard and the pad — *press Enter*.
const KEY_HOVER_OK_KEY: String = "UI_SITE_HOVER_OK_KEY"
const KEY_HOVER_CLOSED: String = "UI_SITE_HOVER_CLOSED"
const KEY_COLLAPSE: String = "UI_SITE_COLLAPSE"
const KEY_EXPAND: String = "UI_SITE_EXPAND"
const PREFIX_REGION: String = "REGION_"
const PLACEHOLDER_NAME: String = "name"
const PLACEHOLDER_REGION: String = "region"
const PLACEHOLDER_REASON: String = "reason"
## first-run.md §1: one row, at most this wide, in the full layout.
const MAX_WIDTH: float = 900.0
const MIN_WIDTH: float = 640.0

## Folded to its title and the way back out; a new request opens unfolded.
var collapsed: bool = false:
	set(value):
		collapsed = value
		if is_node_ready():
			_apply_shape()

@onready var _body: VBoxContainer = %Body
@onready var _row: HBoxContainer = %Row
@onready var _prompt: Label = %SitePromptTitle
@onready var _detail: Label = %SitePromptDetail
@onready var _collapse: IconButton = %SiteCollapse
@onready var _cancel: ConsoleButton = %SiteCancel

var _compact: bool = false
## §4.1: whether the player is on the keyboard or a pad.
var _keyboard: bool = false
var _hovered: int = 0
## The request the strip last showed, so that a new one opens unfolded.
var _shown: SiteRequest = null


func _ready() -> void:
	add_to_group(CoachRing.group(CoachRing.TARGET_SITE_PROMPT))
	_cancel.pressed.connect(_on_cancel_pressed)
	_cancel.label_key = KEY_CANCEL
	_collapse.pressed.connect(_on_collapse_pressed)
	EventBus.run_started.connect(_on_run_started)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.site_select_changed.connect(_on_site_select_changed)
	EventBus.region_hovered.connect(_on_region_hovered)
	EventBus.keyboard_mode_changed.connect(_on_keyboard_mode_changed)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Full layout: one row, centred. Compact: the whole width, the detail on a row
## of its own under the title.
func set_compact(compact: bool) -> void:
	_compact = compact
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_CENTER
	if not is_node_ready():
		return
	_apply_shape()


## Visible exactly while there is a request. The origin one is entered by the
## session on `run_started`, so the strip never has to know about the origin.
func refresh() -> void:
	var request: SiteRequest = Game.site_request
	visible = request != null
	if request != _shown:
		_shown = request
		collapsed = false
	if request == null:
		return
	if request.kind == SiteRequest.KIND_ORIGIN:
		_prompt.text = tr(KEY_ORIGIN_PROMPT)
	else:
		_prompt.text = tr(request.title_key).format({PLACEHOLDER_NAME: tr(request.name_key)})
	_detail.text = _detail_text(request)
	_apply_shape()


## The hovered region, when there is one: whether it will do, and why not.
func _detail_text(request: SiteRequest) -> String:
	if _hovered > 0 and Game.sim != null and _hovered < Game.sim.world.regions.size():
		var region: String = tr(PREFIX_REGION + Game.db.regions[_hovered].id.to_upper())
		var reason: String = request.reason_text(_hovered)
		if reason.is_empty():
			return tr(KEY_HOVER_OK_KEY if _keyboard else KEY_HOVER_OK).format({
				PLACEHOLDER_REGION: region})
		return tr(KEY_HOVER_CLOSED).format({PLACEHOLDER_REGION: region,
			PLACEHOLDER_REASON: reason})
	if request.kind != SiteRequest.KIND_ORIGIN:
		return tr(KEY_DETAIL)
	# scenarios.md §5: a scenario sets the scene in the origin prompt's place.
	var scenario: String = Game.sim.world.setup.scenario if Game.sim != null else ""
	return tr(KEY_ORIGIN_DETAIL if scenario.is_empty() else ScenarioDef.intro_key(scenario))


func _apply_shape() -> void:
	# The router takes the session out of the tree between runs; the strip still
	# hears the bus then, and there is no viewport to measure.
	if not is_inside_tree():
		return
	# Compact puts the detail under the title; the full layout keeps one row.
	var detail_home: Container = _body if _compact else _row
	if _detail.get_parent() != detail_home:
		_detail.get_parent().remove_child(_detail)
		detail_home.add_child(_detail)
		if not _compact:
			_row.move_child(_detail, 1)
	_detail.visible = not collapsed
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _compact \
		else TextServer.AUTOWRAP_OFF
	var request: SiteRequest = Game.site_request
	_cancel.visible = request != null and request.can_cancel() and not collapsed
	_collapse.glyph = Glyphs.Glyph.CHEVRON_RIGHT if collapsed else Glyphs.Glyph.CHEVRON_DOWN
	_collapse.tooltip_key = KEY_EXPAND if collapsed else KEY_COLLAPSE
	if _compact:
		custom_minimum_size.x = 0.0
	else:
		custom_minimum_size.x = 0.0 if collapsed else minf(MAX_WIDTH, maxf(MIN_WIDTH,
			get_viewport_rect().size.x * 0.5))


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()


func _on_site_select_changed(_active: bool) -> void:
	_hovered = 0
	refresh()


func _on_region_hovered(index: int) -> void:
	_hovered = index
	if visible and Game.site_request != null:
		_detail.text = _detail_text(Game.site_request)


func _on_keyboard_mode_changed(keyboard: bool) -> void:
	_keyboard = keyboard
	if visible and Game.site_request != null:
		_detail.text = _detail_text(Game.site_request)


func _on_collapse_pressed() -> void:
	collapsed = not collapsed


func _on_cancel_pressed() -> void:
	Game.site_cancel()
