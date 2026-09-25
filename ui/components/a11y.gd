class_name A11y
extends RefCounted
## The few rules every screen follows for a screen reader (spec accessibility.md
## §3.2): a readout is `{label}: {value}` and reachable by the reader's own
## navigation but not by `Tab`.
##
## Never instantiated; a namespace of static functions.

const KEY_LABEL_VALUE: String = "UI_A11Y_LABEL_VALUE"
const VARIATION_FOCUS_MARGIN: StringName = &"FocusMargin"
## The same room above and below only, for a modal already as wide as a phone.
const VARIATION_FOCUS_MARGIN_VERTICAL: StringName = &"FocusMarginVertical"


## `UI_A11Y_LABEL_VALUE` filled in.
static func label_value(label: String, value: String) -> String:
	return String(TranslationServer.translate(KEY_LABEL_VALUE)).format({
		"label": label, "value": value})


## §3.2 item 4: a readout a player needs — reachable while a screen reader runs,
## never a `Tab` stop — named `{label}: {value}`.
static func readout(control: Control, label: String, value: String) -> void:
	control.focus_mode = Control.FOCUS_ACCESSIBILITY
	control.accessibility_name = label_value(label, value)


## The words a label shows, as a reader should hear them: a `CapsLabel` is named
## in the case the string table spells, every other label by its text.
static func words(label: Label) -> String:
	if label == null:
		return ""
	return label.accessibility_name if not label.accessibility_name.is_empty() else label.text


## accessibility.md §4.2: a scroll container that holds focusable controls
## follows the focus, and its content sits `FOCUS_OUTSET` inside it so a focus
## ring — drawn outside a control — is neither clipped nor scrolled out of view.
## Idempotent; the content keeps its size flags. `sideways` false keeps the
## room above and below only — for content that already fills a phone's width.
static func focus_scroll(scroll: ScrollContainer, sideways: bool = true) -> void:
	if scroll == null:
		return
	scroll.follow_focus = true
	var content: Control = null
	for child: Node in scroll.get_children():
		if child is Control and not child is ScrollBar:
			content = child as Control
			break
	if content == null or (content is MarginContainer and content.theme_type_variation in [
			VARIATION_FOCUS_MARGIN, VARIATION_FOCUS_MARGIN_VERTICAL]):
		return
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "FocusMargin"
	margin.theme_type_variation = VARIATION_FOCUS_MARGIN if sideways \
		else VARIATION_FOCUS_MARGIN_VERTICAL
	margin.size_flags_horizontal = content.size_flags_horizontal
	margin.size_flags_vertical = content.size_flags_vertical
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: int = content.get_index()
	scroll.add_child(margin)
	scroll.move_child(margin, index)
	# Owned like the content, so the content's unique name stays reachable and
	# the scene's ownership stays consistent.
	margin.owner = content.owner
	content.reparent(margin, false)
