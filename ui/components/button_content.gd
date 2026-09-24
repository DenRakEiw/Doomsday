class_name ButtonContent
extends RefCounted
## A `Button` that carries a laid-out child instead of its own text.
##
## A `Button` is not a container: it does not measure what it carries, so a
## caption and a value stacked inside it run out of it as soon as the type grows
## (the 150 % screenshots of S4.9) or a German word is longer. `fit` makes the
## button's minimum follow its content's, now and whenever the content's changes —
## the rule the tech tree's tabs, the analysis log and the status strip each had a
## copy of.


## Keeps `button`'s minimum at least `content`'s combined minimum on the chosen
## axes, and never below the hit target's height.
static func fit(button: Button, content: Control, width: bool = true,
		height: bool = true) -> void:
	var apply: Callable = func() -> void:
		var wanted: Vector2 = content.get_combined_minimum_size()
		if width:
			button.custom_minimum_size.x = wanted.x
		if height:
			button.custom_minimum_size.y = maxf(wanted.y, float(UiTokens.HIT_MIN))
	content.minimum_size_changed.connect(apply)
	apply.call()
