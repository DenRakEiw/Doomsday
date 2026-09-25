class_name HelpButton
extends IconButton
## The **?** in the header of a dense panel (`first-run.md` §6.7): it asks for
## the *How to play* page of its surface, as `F1` does from the keyboard.
##
## Only the tech tree, the containment panel, the analysis panel and the region
## panel carry one (§6.0 item 5); it sits directly before their close button.

const KEY_TIP: String = "UI_HELP_BUTTON_TIP"

## One of `HelpPages.CONTEXTS`.
@export var context: String = HelpPages.CONTEXT_SESSION


func _init() -> void:
	glyph = Glyphs.Glyph.HELP
	tooltip_key = KEY_TIP


func _ready() -> void:
	super()
	pressed.connect(_on_pressed)


## A button for `context_id`, placed directly before `close` in its row.
static func before(close: Control, context_id: String) -> HelpButton:
	var button: HelpButton = HelpButton.new()
	button.context = context_id
	# The close button's own alignment, so the two sit on one line.
	button.size_flags_vertical = close.size_flags_vertical
	var row: Node = close.get_parent()
	row.add_child(button)
	row.move_child(button, close.get_index())
	return button


func _on_pressed() -> void:
	EventBus.help_requested.emit(HelpPages.page_for_context(context))
