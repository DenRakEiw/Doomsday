class_name ToggleGroup
extends RefCounted
## Choosing one toggle of a `ButtonGroup` from code.
##
## A group is exclusive only against a click: `set_pressed_no_signal(true)`
## presses a button and leaves the one before it pressed too, so a tab chosen
## by the code (a Codex tab, a difficulty) was drawn next to the last one
## (PROGRESS.md *Known issues*, S5.8 and S6.P4). `press` writes the whole group,
## the way the top bar's speed row and the setup's scenario row do by hand.
##
## Never instantiated; a namespace of static functions.


## Presses `button` without a signal and lets every other button of its group
## go. A button without a group is simply pressed.
static func press(button: BaseButton) -> void:
	var group: ButtonGroup = button.button_group
	if group != null:
		for other: BaseButton in group.get_buttons():
			if other != button:
				other.set_pressed_no_signal(false)
	button.set_pressed_no_signal(true)
