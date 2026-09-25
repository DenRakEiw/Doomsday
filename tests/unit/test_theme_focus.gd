extends GutTest
## S6.8 — the focus ring sits outside every focusable control (accessibility.md
## §4.2), so it shows on a filled button, a toggled one and any surface.

## Every type variation a focusable control uses.
const FOCUSABLE: Array[String] = ["ConsoleButton", "ConsoleButtonPrimary",
	"ConsoleButtonCompact", "ConsoleButtonPrimaryCompact", "ConsoleButtonFlat",
	"ConsoleButtonAlert", "IconButton", "TechNode", "TechNodeLocked", "TechNodeAffordable",
	"TechNodeOwned", "ArchitectureCard", "ChartFrame"]


func test_every_focusable_type_has_an_outer_ring() -> void:
	var theme: Theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD, 1.0)
	for type: String in FOCUSABLE:
		var box: StyleBoxFlat = theme.get_stylebox("focus", type) as StyleBoxFlat
		assert_not_null(box, type)
		if box == null:
			continue
		assert_false(box.draw_center, type)
		assert_eq(box.border_width_left, UiTokens.BORDER_FOCUS, type)
		assert_eq(box.expand_margin_left, float(UiTokens.FOCUS_OUTSET), type)
		assert_eq(box.expand_margin_bottom, float(UiTokens.FOCUS_OUTSET), type)
		assert_eq(box.border_color, UiTokens.color(&"ACCENT"), type)
