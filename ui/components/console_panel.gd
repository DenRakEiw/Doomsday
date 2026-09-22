class_name ConsolePanel
extends PanelContainer
## A surface with an optional title (spec ui-foundation.md §4.1).
##
## The panel owns a `VBoxContainer` called `Content`: whatever the scene puts
## inside the panel lands in it, and the title and its rule are inserted above.
## A scene therefore authors its children directly under the panel and does not
## have to repeat the same wrapper five times — and code that fills a panel at
## runtime adds to `content`.
##
## `alert` switches the border to `ALERT` through a theme variation, because a
## per-node `StyleBox` override would be invisible in review and unskinnable
## (UI.md §4).

const VARIATION: StringName = &"ConsolePanel"
const VARIATION_RAISED: StringName = &"ConsolePanelRaised"
const SUFFIX_ALERT: String = "Alert"
const RULE_VARIATION: StringName = &"PanelRule"
const CONTENT_VARIATION: StringName = &"PanelContent"
const CONTENT_NAME: StringName = &"Content"

## §4.1: the same panel on the raised surface, used by the top bar and the dock.
@export var raised: bool = false:
	set(value):
		raised = value
		_apply_variation()

## The border turns `ALERT` — "something is happening in here", never permanent.
@export var alert: bool = false:
	set(value):
		alert = value
		_apply_variation()

## The optional title, uppercased like every `TYPE_LABEL` (§3.2).
@export var title_key: String = "":
	set(value):
		title_key = value
		_apply_title()

## Where children live. Null until `_ready` has built it.
var content: VBoxContainer = null

var _title: CapsLabel = null
var _rule: HSeparator = null


func _ready() -> void:
	_build_content()
	_apply_variation()
	_apply_title()


## Moves whatever the scene authored inside the panel into the content box.
func _build_content() -> void:
	if content != null:
		return
	var authored: Array[Node] = get_children()
	content = VBoxContainer.new()
	content.name = CONTENT_NAME
	# The gap between rows is the theme's, like everything else about the panel.
	content.theme_type_variation = CONTENT_VARIATION
	add_child(content)
	for child: Node in authored:
		remove_child(child)
		content.add_child(child)
		# Children authored in a scene keep their owner, or they vanish from it.
		if child.owner == null:
			child.owner = owner


func _apply_variation() -> void:
	var base: String = VARIATION_RAISED if raised else VARIATION
	theme_type_variation = StringName(base + (SUFFIX_ALERT if alert else ""))


## The title is a `LabelCaps` and a rule, always the first two rows (§4.1).
func _apply_title() -> void:
	if content == null:
		return
	if title_key.is_empty():
		if _title != null:
			_title.queue_free()
			_rule.queue_free()
			_title = null
			_rule = null
		return
	if _title == null:
		_title = CapsLabel.new()
		_rule = HSeparator.new()
		_rule.theme_type_variation = RULE_VARIATION
		content.add_child(_title)
		content.add_child(_rule)
		content.move_child(_title, 0)
		content.move_child(_rule, 1)
	_title.label_key = title_key
