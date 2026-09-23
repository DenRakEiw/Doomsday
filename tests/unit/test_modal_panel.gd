extends GutTest
## S4.9 — a modal is as wide as the spec allows and never wider than the screen.


func test_a_wide_screen_gets_the_spec_width() -> void:
	assert_eq(ModalPanel.width_for(1920.0), float(UiTokens.MODAL_MAX_WIDTH))


func test_a_phone_gets_the_screen_less_two_gutters() -> void:
	assert_eq(ModalPanel.width_for(400.0), 400.0 - float(UiTokens.GUTTER) * 2.0)


func test_a_screen_narrower_than_two_gutters_gets_nothing_negative() -> void:
	assert_eq(ModalPanel.width_for(20.0), 0.0)
