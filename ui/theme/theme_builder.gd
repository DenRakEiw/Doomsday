class_name ThemeBuilder
extends RefCounted
## Builds the project-wide `Theme` out of `UiTokens` (spec ui-foundation.md §3.8).
##
## Five partial themes are composed with `Theme.merge_with()` in the order
## colours → typography → panels → buttons → bars, so that a reviewer can read
## one concern at a time instead of one enormous resource.
##
## `tools/build_theme.gd` saves the result as `ui/theme/doomsday.tres`, which
## `project.godot` names as `gui/theme/custom` — that, and only that, makes the
## type variations appear in the editor's dropdown (UI.md §4). The session root
## assigns `build()` again at runtime so the phase swap of D3.3 has one place to
## go.
##
## Nothing here invents a value: every colour, size, spacing and radius comes
## from `UiTokens`.

## The token set of this document. D3.3 delivers `"open"`; until then every other
## name falls back to this one with a warning (§3.7).
const VARIANT_COLD: String = "cold"
const VARIANTS: Array[String] = [VARIANT_COLD]

const FONT_MONO_REGULAR: String = "res://assets/fonts/JetBrainsMono-Regular.ttf"
const FONT_MONO_MEDIUM: String = "res://assets/fonts/JetBrainsMono-Medium.ttf"
const FONT_MONO_BOLD: String = "res://assets/fonts/JetBrainsMono-Bold.ttf"
## Space Grotesk 2.0.0 ships no static SemiBold, so both display weights are cut
## from the variable font (see PROGRESS.md, *Deviations*).
const FONT_DISPLAY_VARIABLE: String = "res://assets/fonts/SpaceGrotesk-Variable.ttf"

## OpenType weight axis. The tag is the four characters of `wght` packed
## big-endian, which is the encoding the format itself defines.
const TAG_WEIGHT: int = 0x77676874
const WEIGHT_MEDIUM: int = 500
const WEIGHT_SEMI_BOLD: int = 600

# ------------------------------------------------------------ theme item names

const COLOR_FONT: String = "font_color"
const COLOR_FONT_HOVER: String = "font_hover_color"
const COLOR_FONT_PRESSED: String = "font_pressed_color"
const COLOR_FONT_HOVER_PRESSED: String = "font_hover_pressed_color"
const COLOR_FONT_FOCUS: String = "font_focus_color"
const COLOR_FONT_DISABLED: String = "font_disabled_color"
## The three colours of a `StatBar` (§4.4) plus the trough's edge, which the
## spec names in prose but not as an item.
const COLOR_FILL: String = "fill"
const COLOR_TROUGH: String = "trough"
const COLOR_TROUGH_BORDER: String = "trough_border"
const COLOR_TEXT: String = "text"

const STYLE_PANEL: String = "panel"
const STYLE_NORMAL: String = "normal"
const STYLE_HOVER: String = "hover"
const STYLE_PRESSED: String = "pressed"
const STYLE_FOCUS: String = "focus"
const STYLE_DISABLED: String = "disabled"
const STYLE_SEPARATOR: String = "separator"

const ITEM_FONT: String = "font"
const ITEM_FONT_SIZE: String = "font_size"

const CONST_LINE_SPACING: String = "line_spacing"
const CONST_SEPARATION: String = "separation"
## `StatBar` geometry, so that the component draws no number of its own (§4.4).
const CONST_BAR_HEIGHT: String = "bar_height"
const CONST_BAR_RADIUS: String = "bar_radius"
const CONST_BAR_BORDER: String = "bar_border"
const CONST_MIN_HEIGHT: String = "min_height"
const CONST_COMPACT_HEIGHT: String = "compact_height"
const CONST_ROW_GAP: String = "row_gap"

# ------------------------------------------------------------- type variations

const PANEL_CONTAINER: String = "PanelContainer"
const BUTTON: String = "Button"
const LABEL: String = "Label"
const CONTROL: String = "Control"
const H_SEPARATOR: String = "HSeparator"

const STAT_BAR: String = "StatBar"
const VALUE_LABEL: String = "ValueLabel"
## m3-screens §3.4: the node of a technology tree, and the three states that
## vary it. A state is a variation, never a per-node override.
const TECH_NODE: String = "TechNode"
const TECH_NODE_STATES: Array[String] = ["", "Locked", "Affordable", "Owned"]
## The four colour states a `ValueLabel` can take (§4.5), as suffixes on both the
## normal and the large variation. A `Label` has one colour, so the state is the
## whole label's, not just the delta's.
const VALUE_STATES: Array[String] = ["", "Up", "Down", "Muted"]

## Every type variation of §3.8 and the type it varies. `build` registers them
## on the finished theme; the test compares this list against the spec.
const VARIATIONS: Dictionary[String, String] = {
	"ConsolePanel": PANEL_CONTAINER,
	"ConsolePanelAlert": PANEL_CONTAINER,
	"ConsolePanelRaised": PANEL_CONTAINER,
	"ConsolePanelRaisedAlert": PANEL_CONTAINER,
	"Ticker": PANEL_CONTAINER,
	"Chip": PANEL_CONTAINER,
	"ChipAccent": PANEL_CONTAINER,
	"ChipAlert": PANEL_CONTAINER,
	"PanelRule": H_SEPARATOR,
	"PanelContent": "VBoxContainer",
	"Gutter": "MarginContainer",
	"GutterTight": "MarginContainer",
	"Stack": "VBoxContainer",
	"StackTight": "VBoxContainer",
	"Flush": "VBoxContainer",
	"Row": "HBoxContainer",
	"RowWide": "HBoxContainer",
	"RowTight": "HBoxContainer",
	"RowSnug": "HBoxContainer",
	"FlowSnug": "HFlowContainer",
	"Flow": "HFlowContainer",
	"Grid": "GridContainer",
	"ConsoleButton": BUTTON,
	"ConsoleButtonPrimary": BUTTON,
	"ConsoleButtonCompact": BUTTON,
	"ConsoleButtonPrimaryCompact": BUTTON,
	"IconButton": BUTTON,
	"StatBar": CONTROL,
	"StatBarPenetration": STAT_BAR,
	"StatBarFootprint": STAT_BAR,
	"StatBarHarm": STAT_BAR,
	"StatBarRows": "VBoxContainer",
	"StatBarRow": "HBoxContainer",
	"ValueLabel": LABEL,
	"ValueLabelUp": VALUE_LABEL,
	"ValueLabelDown": VALUE_LABEL,
	"ValueLabelMuted": VALUE_LABEL,
	"ValueLabelLarge": VALUE_LABEL,
	"ValueLabelLargeUp": VALUE_LABEL,
	"ValueLabelLargeDown": VALUE_LABEL,
	"ValueLabelLargeMuted": VALUE_LABEL,
	"LabelCaps": LABEL,
	"LabelCaption": LABEL,
	"LabelDisplay": LABEL,
	"LabelDisplayXL": LABEL,
	"LabelHeading": LABEL,
	"ChipLabel": "LabelCaps",
	"ChipLabelAccent": "LabelCaps",
	"ChipLabelAlert": "LabelCaps",
	"MapTooltip": PANEL_CONTAINER,
	"MapTooltipLabel": "LabelCaption",
	"LabelCaptionAlert": "LabelCaption",
	"ConsoleButtonFlat": BUTTON,
	"TechGrid": "GridContainer",
	"TechGridCompact": "GridContainer",
	"TechNode": BUTTON,
	"TechNodeLocked": TECH_NODE,
	"TechNodeAffordable": TECH_NODE,
	"TechNodeOwned": TECH_NODE,
	"TechNodeName": "LabelCaps",
	"TechNodeNameLocked": "LabelCaps",
	"TechNodeCost": VALUE_LABEL,
	"TechNodeCostLocked": VALUE_LABEL,
	"TechNodeCostAffordable": VALUE_LABEL,
	"TechNodeTag": "LabelCaption",
	"TechNodeFootprint": "LabelCaption",
}


## The theme for a token set. An unknown variant is the caller's mistake, not the
## player's, so it warns and hands back the cold set rather than failing (§3.7).
static func build(variant: String) -> Theme:
	if not VARIANTS.has(variant):
		push_warning("theme variant '%s' does not exist yet — using '%s'" % [
			variant, VARIANT_COLD])
	var theme: Theme = Theme.new()
	for partial: Theme in [_colours(), _typography(), _panels(), _buttons(), _bars()]:
		theme.merge_with(partial)
	for name: String in VARIATIONS:
		theme.set_type_variation(name, VARIATIONS[name])
	theme.default_font = _mono(FONT_MONO_REGULAR)
	theme.default_font_size = UiTokens.TYPE_BODY
	return theme


# ------------------------------------------------------------------ partial 1


## Every colour the interface draws text and data in. Surfaces come with their
## `StyleBox`es in the later partials.
static func _colours() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_color(COLOR_FONT, LABEL, UiTokens.TEXT_0)
	theme.set_color(COLOR_FONT, "LabelCaps", UiTokens.TEXT_1)
	theme.set_color(COLOR_FONT, "LabelCaption", UiTokens.TEXT_2)
	# m3-screens §3.3: the reason a purchase was refused. Red is a moment, and a
	# refusal is one.
	theme.set_color(COLOR_FONT, "LabelCaptionAlert", UiTokens.ALERT)
	theme.set_color(COLOR_FONT, "LabelDisplay", UiTokens.TEXT_0)
	theme.set_color(COLOR_FONT, "LabelDisplayXL", UiTokens.TEXT_0)
	theme.set_color(COLOR_FONT, "LabelHeading", UiTokens.TEXT_0)
	theme.set_color(COLOR_FONT, "ChipLabel", UiTokens.TEXT_1)
	theme.set_color(COLOR_FONT, "ChipLabelAccent", UiTokens.ACCENT)
	theme.set_color(COLOR_FONT, "ChipLabelAlert", UiTokens.ALERT)
	theme.set_color(COLOR_FONT, "Ticker", UiTokens.TEXT_1)
	# §7.7: the tooltip is a caption on a chip-shaped box, but it is read over a
	# moving map — so `TEXT_0`, not the caption's `TEXT_2`.
	theme.set_color(COLOR_FONT, "MapTooltipLabel", UiTokens.TEXT_0)

	# m3-screens §3.4's table: a tech node colours its name and its cost by the
	# state it is in, and a `Label` has one colour — so each is its own variation.
	theme.set_color(COLOR_FONT, "TechNodeName", UiTokens.TEXT_0)
	theme.set_color(COLOR_FONT, "TechNodeNameLocked", UiTokens.TEXT_2)
	theme.set_color(COLOR_FONT, "TechNodeCost", UiTokens.TEXT_1)
	theme.set_color(COLOR_FONT, "TechNodeCostLocked", UiTokens.TEXT_2)
	theme.set_color(COLOR_FONT, "TechNodeCostAffordable", UiTokens.ACCENT)
	theme.set_color(COLOR_FONT, "TechNodeTag", UiTokens.ACCENT)
	theme.set_color(COLOR_FONT, "TechNodeFootprint", UiTokens.TEXT_2)

	# §4.5: the delta's colour is the label's colour, because a `Label` has one.
	var value_colours: Dictionary[String, Color] = {
		"": UiTokens.TEXT_0,
		"Up": UiTokens.ACCENT,
		"Down": UiTokens.MAP_DEATH,
		"Muted": UiTokens.TEXT_2,
	}
	for state: String in VALUE_STATES:
		theme.set_color(COLOR_FONT, VALUE_LABEL + state, value_colours[state])
		theme.set_color(COLOR_FONT, VALUE_LABEL + "Large" + state, value_colours[state])
	return theme


# ------------------------------------------------------------------ partial 2


## The type scale of §3.2. Line heights are multipliers there and extra pixels
## here, which is what a `Label` understands.
static func _typography() -> Theme:
	var theme: Theme = Theme.new()
	var mono_regular: FontFile = _mono(FONT_MONO_REGULAR)
	var mono_medium: FontFile = _mono(FONT_MONO_MEDIUM)
	var mono_bold: FontFile = _mono(FONT_MONO_BOLD)
	var caps: FontVariation = _tracked(mono_medium, UiTokens.TYPE_LABEL)
	var display: FontVariation = _display(WEIGHT_SEMI_BOLD)
	var heading: FontVariation = _display(WEIGHT_MEDIUM)

	_type(theme, LABEL, mono_regular, UiTokens.TYPE_BODY, UiTokens.LINE_BODY)
	_type(theme, "LabelCaps", caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	_type(theme, "LabelCaption", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelCaptionAlert", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "MapTooltipLabel", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelDisplay", display, UiTokens.TYPE_DISPLAY, UiTokens.LINE_DISPLAY)
	_type(theme, "LabelDisplayXL", display, UiTokens.TYPE_DISPLAY_XL, UiTokens.LINE_DISPLAY_XL)
	_type(theme, "LabelHeading", heading, UiTokens.TYPE_HEADING, UiTokens.LINE_HEADING)
	for chip: String in ["ChipLabel", "ChipLabelAccent", "ChipLabelAlert"]:
		_type(theme, chip, caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	for state: String in VALUE_STATES:
		_type(theme, VALUE_LABEL + state, mono_medium, UiTokens.TYPE_DATA, UiTokens.LINE_DATA)
		_type(theme, VALUE_LABEL + "Large" + state, mono_bold, UiTokens.TYPE_DATA_LG,
			UiTokens.LINE_DATA_LG)

	# A button's label is `TYPE_LABEL` (§4.2); the icon buttons carry no text but
	# inherit the same entry so that nothing falls back to the default font.
	for button: String in ["ConsoleButton", "ConsoleButtonPrimary", "ConsoleButtonCompact",
			"ConsoleButtonPrimaryCompact", "IconButton"]:
		theme.set_font(ITEM_FONT, button, caps)
		theme.set_font_size(ITEM_FONT_SIZE, button, UiTokens.TYPE_LABEL)
	_type(theme, "Ticker", mono_regular, UiTokens.TYPE_BODY, UiTokens.LINE_BODY)

	# A tech node's own labels: the name tracks like every `LabelCaps`, the cost
	# is data, the two captions are captions (m3-screens §3.4).
	for name: String in ["TechNodeName", "TechNodeNameLocked"]:
		_type(theme, name, caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	for cost: String in ["TechNodeCost", "TechNodeCostLocked", "TechNodeCostAffordable"]:
		_type(theme, cost, mono_medium, UiTokens.TYPE_DATA, UiTokens.LINE_DATA)
	for caption: String in ["TechNodeTag", "TechNodeFootprint"]:
		_type(theme, caption, mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	# §3.6 item 6: a row that reads as a line of text, not as a shouted label.
	theme.set_font(ITEM_FONT, "ConsoleButtonFlat", mono_regular)
	theme.set_font_size(ITEM_FONT_SIZE, "ConsoleButtonFlat", UiTokens.TYPE_BODY)
	return theme


# ------------------------------------------------------------------ partial 3


## Panels, chips, the ticker strip and the rule under a panel title (§4.1, §4.7).
static func _panels() -> Theme:
	var theme: Theme = Theme.new()
	var pad: Vector2i = Vector2i(UiTokens.SPACE_4, UiTokens.SPACE_4)
	theme.set_stylebox(STYLE_PANEL, "ConsolePanel",
		_flat(UiTokens.BG_2, UiTokens.LINE_1, UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelAlert",
		_flat(UiTokens.BG_2, UiTokens.ALERT, UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelRaised",
		_flat(UiTokens.BG_3, UiTokens.LINE_1, UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelRaisedAlert",
		_flat(UiTokens.BG_3, UiTokens.ALERT, UiTokens.BORDER, UiTokens.RADIUS_M, pad))

	var chip_pad: Vector2i = Vector2i(UiTokens.SPACE_2, UiTokens.SPACE_1)
	theme.set_stylebox(STYLE_PANEL, "Chip",
		_flat(UiTokens.BG_3, UiTokens.LINE_1, UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	theme.set_stylebox(STYLE_PANEL, "ChipAccent",
		_flat(UiTokens.BG_3, UiTokens.ACCENT_DIM, UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	theme.set_stylebox(STYLE_PANEL, "ChipAlert",
		_flat(UiTokens.BG_3, UiTokens.ALERT, UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	# §7.7: chip-shaped, but on `BG_2` — it sits over the map, not on a panel.
	theme.set_stylebox(STYLE_PANEL, "MapTooltip",
		_flat(UiTokens.BG_2, UiTokens.LINE_1, UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))

	# §5.5: the ticker is a strip with a top border and no other edge.
	var ticker: StyleBoxFlat = _flat(UiTokens.BG_2, UiTokens.LINE_1, 0, 0,
		Vector2i(UiTokens.SPACE_4, 0))
	ticker.border_width_top = UiTokens.BORDER
	theme.set_stylebox(STYLE_PANEL, "Ticker", ticker)

	var rule: StyleBoxLine = StyleBoxLine.new()
	rule.color = UiTokens.LINE_0
	rule.thickness = UiTokens.BORDER
	theme.set_stylebox(STYLE_SEPARATOR, "PanelRule", rule)
	theme.set_constant(CONST_SEPARATION, "PanelRule", UiTokens.SPACE_2 * 2 + UiTokens.BORDER)
	# The rows inside a panel, so that `ConsolePanel` needs no node override.
	theme.set_constant(CONST_SEPARATION, "PanelContent", UiTokens.SPACE_3)
	# Two layout primitives every screen needs: the gutter a block keeps from the
	# edge (§3.3) and the gap between two blocks.
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		theme.set_constant(side, "Gutter", UiTokens.GUTTER)
		# m3-screens §3.4: a tech node's content sits `SPACE_3` inside its cell,
		# which is what leaves 176 px for the longest German name.
		theme.set_constant(side, "GutterTight", UiTokens.SPACE_3)
	theme.set_constant(CONST_SEPARATION, "Stack", UiTokens.SPACE_5)
	theme.set_constant(CONST_SEPARATION, "Row", UiTokens.SPACE_3)
	# §5 asks for three more gaps than §3.8 named: between the cells of the top
	# bar and the bars of the stat row (`SPACE_5`), between the buttons of a
	# speed group (`SPACE_1`), and between the dock's destinations (`SPACE_2`).
	theme.set_constant(CONST_SEPARATION, "RowWide", UiTokens.SPACE_5)
	theme.set_constant(CONST_SEPARATION, "RowTight", UiTokens.SPACE_1)
	# m3-screens §3.2's tab row sits between the two: closer than blocks, wider
	# than the buttons of a speed group.
	theme.set_constant(CONST_SEPARATION, "RowSnug", UiTokens.SPACE_2)
	for axis: String in ["h_separation", "v_separation"]:
		theme.set_constant(axis, "FlowSnug", UiTokens.SPACE_2)
	theme.set_constant(CONST_SEPARATION, "StackTight", UiTokens.SPACE_2)
	# §5.7's strips touch: a gap between the stat row and the ticker would be a
	# stripe of map between two panels.
	theme.set_constant(CONST_SEPARATION, "Flush", 0)
	# A flow row wraps, so it has a gap in both directions — and so does §5.6's
	# two-column attribute grid.
	theme.set_constant("h_separation", "Flow", UiTokens.SPACE_3)
	theme.set_constant("v_separation", "Flow", UiTokens.SPACE_3)
	theme.set_constant("h_separation", "Grid", UiTokens.SPACE_4)
	theme.set_constant("v_separation", "Grid", UiTokens.SPACE_2)
	# m3-screens §3.2: the gap between two cells of a tree, in both layouts. The
	# lines control is given the same numbers, so the two never drift apart.
	for axis: String in ["h_separation", "v_separation"]:
		theme.set_constant(axis, "TechGrid", UiTokens.SPACE_3)
		theme.set_constant(axis, "TechGridCompact", UiTokens.SPACE_2)
	return theme


# ------------------------------------------------------------------ partial 4


## The state tables of §4.2 and §4.3.
static func _buttons() -> Theme:
	var theme: Theme = Theme.new()
	var pad: Vector2i = Vector2i(UiTokens.SPACE_5, UiTokens.SPACE_3)
	_button_styles(theme, "ConsoleButton", pad, UiTokens.BG_3, UiTokens.BG_4,
		UiTokens.accent_wash(), UiTokens.LINE_1, UiTokens.LINE_2, UiTokens.ACCENT)
	_button_colours(theme, "ConsoleButton", UiTokens.TEXT_0, UiTokens.TEXT_0, UiTokens.ACCENT)

	# The primary button is lit at rest, so its states brighten rather than fill.
	_button_styles(theme, "ConsoleButtonPrimary", pad, UiTokens.ACCENT, UiTokens.ACCENT_HOVER,
		UiTokens.ACCENT_PRESSED, UiTokens.ACCENT, UiTokens.ACCENT_HOVER, UiTokens.ACCENT_PRESSED)
	_button_colours(theme, "ConsoleButtonPrimary", UiTokens.INK, UiTokens.INK, UiTokens.INK)

	# §5.7's compact dock is three buttons in 400 px, and the three German words
	# do not fit the padding above. Everything else about them is the same, so
	# the compact form is a variation and not a second component.
	var tight: Vector2i = Vector2i(UiTokens.SPACE_3, UiTokens.SPACE_3)
	_button_styles(theme, "ConsoleButtonCompact", tight, UiTokens.BG_3, UiTokens.BG_4,
		UiTokens.accent_wash(), UiTokens.LINE_1, UiTokens.LINE_2, UiTokens.ACCENT)
	_button_colours(theme, "ConsoleButtonCompact", UiTokens.TEXT_0, UiTokens.TEXT_0,
		UiTokens.ACCENT)
	_button_styles(theme, "ConsoleButtonPrimaryCompact", tight, UiTokens.ACCENT,
		UiTokens.ACCENT_HOVER, UiTokens.ACCENT_PRESSED, UiTokens.ACCENT, UiTokens.ACCENT_HOVER,
		UiTokens.ACCENT_PRESSED)
	_button_colours(theme, "ConsoleButtonPrimaryCompact", UiTokens.INK, UiTokens.INK,
		UiTokens.INK)

	# m3-screens §3.6 item 6: a prerequisite row. No border, so the eye reads the
	# column of rows as a list and not as a row of buttons.
	_button_styles(theme, "ConsoleButtonFlat", tight, UiTokens.BG_2, UiTokens.BG_3,
		UiTokens.accent_wash(), Color.TRANSPARENT, Color.TRANSPARENT, UiTokens.ACCENT)
	_button_colours(theme, "ConsoleButtonFlat", UiTokens.TEXT_0, UiTokens.TEXT_0,
		UiTokens.ACCENT)

	# m3-screens §3.4: one variation per state, hover a surface step lighter and a
	# border step stronger. `TechNode` itself is the AVAILABLE state.
	var cell: Vector2i = Vector2i(UiTokens.SPACE_3, UiTokens.SPACE_3)
	_button_styles(theme, "TechNode", cell, UiTokens.BG_3, UiTokens.BG_4,
		UiTokens.accent_wash(), UiTokens.LINE_1, UiTokens.LINE_2, UiTokens.ACCENT)
	_button_styles(theme, "TechNodeLocked", cell, UiTokens.BG_2, UiTokens.BG_3,
		UiTokens.accent_wash(), UiTokens.LINE_0, UiTokens.LINE_1, UiTokens.ACCENT)
	_button_styles(theme, "TechNodeAffordable", cell, UiTokens.BG_3, UiTokens.BG_4,
		UiTokens.accent_wash(), UiTokens.ACCENT_DIM, UiTokens.ACCENT, UiTokens.ACCENT)
	_button_styles(theme, "TechNodeOwned", cell, UiTokens.accent_wash(),
		UiTokens.accent_wash_raised(), UiTokens.accent_wash_raised(), UiTokens.ACCENT,
		UiTokens.ACCENT, UiTokens.ACCENT)
	for state: String in TECH_NODE_STATES:
		# The node's text lives in its child labels; the button's own colours are
		# there so that nothing falls back to the default font colour.
		_button_colours(theme, TECH_NODE + state, UiTokens.TEXT_0, UiTokens.TEXT_0,
			UiTokens.TEXT_0)

	# An icon button has no text, so its padding is zero: the glyph is drawn in a
	# centred box of its own (§4.3).
	_button_styles(theme, "IconButton", Vector2i.ZERO, UiTokens.BG_3, UiTokens.BG_4,
		UiTokens.accent_wash(), UiTokens.LINE_1, UiTokens.LINE_2, UiTokens.ACCENT)
	_button_colours(theme, "IconButton", UiTokens.TEXT_0, UiTokens.TEXT_0, UiTokens.ACCENT)
	return theme


# ------------------------------------------------------------------ partial 5


## `StatBar`: the colours it draws with and the geometry it draws to (§4.4).
static func _bars() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_color(COLOR_FILL, STAT_BAR, UiTokens.ACCENT)
	theme.set_color(COLOR_TROUGH, STAT_BAR, UiTokens.BG_3)
	theme.set_color(COLOR_TROUGH_BORDER, STAT_BAR, UiTokens.LINE_0)
	theme.set_color(COLOR_TEXT, STAT_BAR, UiTokens.TEXT_0)
	theme.set_constant(CONST_BAR_HEIGHT, STAT_BAR, UiTokens.BAR_HEIGHT)
	theme.set_constant(CONST_BAR_RADIUS, STAT_BAR, UiTokens.RADIUS_S)
	theme.set_constant(CONST_BAR_BORDER, STAT_BAR, UiTokens.BORDER)
	theme.set_constant(CONST_MIN_HEIGHT, STAT_BAR, UiTokens.BAR_MIN_HEIGHT)
	theme.set_constant(CONST_COMPACT_HEIGHT, STAT_BAR, UiTokens.BAR_COMPACT_HEIGHT)
	# The two rows of a bar and the one row of its compact form (§5.7).
	theme.set_constant(CONST_SEPARATION, "StatBarRows", UiTokens.SPACE_1)
	theme.set_constant(CONST_SEPARATION, "StatBarRow", UiTokens.SPACE_2)
	theme.set_color(COLOR_FILL, "StatBarPenetration", UiTokens.STAT_PENETRATION)
	theme.set_color(COLOR_FILL, "StatBarFootprint", UiTokens.STAT_FOOTPRINT)
	theme.set_color(COLOR_FILL, "StatBarHarm", UiTokens.STAT_HARM)
	return theme


# ----------------------------------------------------------------- the pieces


## One font entry: family, size, and the line height of §3.2 as the extra pixels
## a `Label` puts between two lines.
static func _type(theme: Theme, type: String, font: Font, size: int, line: float) -> void:
	theme.set_font(ITEM_FONT, type, font)
	theme.set_font_size(ITEM_FONT_SIZE, type, size)
	theme.set_constant(CONST_LINE_SPACING, type, roundi(float(size) * (line - 1.0)))


static func _button_styles(theme: Theme, type: String, pad: Vector2i, normal: Color,
		hover: Color, pressed: Color, border: Color, border_hover: Color,
		border_pressed: Color) -> void:
	var radius: int = UiTokens.RADIUS_S
	var width: int = UiTokens.BORDER
	theme.set_stylebox(STYLE_NORMAL, type, _flat(normal, border, width, radius, pad))
	theme.set_stylebox(STYLE_HOVER, type, _flat(hover, border_hover, width, radius, pad))
	theme.set_stylebox(STYLE_PRESSED, type, _flat(pressed, border_pressed, width, radius, pad))
	theme.set_stylebox(STYLE_DISABLED, type,
		_flat(UiTokens.BG_2, UiTokens.LINE_0, width, radius, pad))
	# Focus draws on top of whichever state is underneath, so it is a border and
	# nothing else (§4.2).
	theme.set_stylebox(STYLE_FOCUS, type, _flat(Color.TRANSPARENT, UiTokens.ACCENT,
		UiTokens.BORDER_FOCUS, radius, pad))


static func _button_colours(theme: Theme, type: String, normal: Color, hover: Color,
		pressed: Color) -> void:
	theme.set_color(COLOR_FONT, type, normal)
	theme.set_color(COLOR_FONT_HOVER, type, hover)
	theme.set_color(COLOR_FONT_PRESSED, type, pressed)
	theme.set_color(COLOR_FONT_HOVER_PRESSED, type, pressed)
	theme.set_color(COLOR_FONT_FOCUS, type, normal)
	theme.set_color(COLOR_FONT_DISABLED, type, UiTokens.TEXT_2)


## Every surface in the game is a `StyleBoxFlat` (§3.8) — no texture anywhere.
static func _flat(bg: Color, border: Color, width: int, radius: int,
		pad: Vector2i) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = float(pad.x)
	box.content_margin_right = float(pad.x)
	box.content_margin_top = float(pad.y)
	box.content_margin_bottom = float(pad.y)
	return box


static func _mono(path: String) -> FontFile:
	return load(path) as FontFile


## Tracking is an em value in §3.2 and whole pixels of glyph spacing here.
static func _tracked(base: FontFile, size: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = base
	font.spacing_glyph = roundi(float(size) * UiTokens.TRACKING_LABEL)
	return font


## A weight cut from the variable display font.
static func _display(weight: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = load(FONT_DISPLAY_VARIABLE) as FontFile
	font.variation_opentype = {TAG_WEIGHT: weight}
	return font
