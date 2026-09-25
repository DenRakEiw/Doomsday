class_name ModalPanel
extends PanelContainer
## The panel of a modal (m3-screens §7): `MODAL_MAX_WIDTH` wide, or the screen
## less a gutter on each side where the screen is narrower.
##
## Every modal used to set the 560 px itself, and on a 400 px phone each of them
## ran off both edges (S4.9 screenshots). The width follows the window, so a
## rotated phone or a resized window is fitted again.


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


## accessibility.md §8.1: a new text size arrives as a new theme.
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_fit()


## The width of a modal on a viewport `viewport_width` logical pixels wide. Since
## S6.8 the maximum grows with the text size (accessibility.md §8.1).
static func width_for(viewport_width: float) -> float:
	return maxf(minf(UiTokens.text_width(float(UiTokens.MODAL_MAX_WIDTH)),
		viewport_width - float(UiTokens.GUTTER) * 2.0), 0.0)


func _fit() -> void:
	custom_minimum_size.x = width_for(get_viewport_rect().size.x)
