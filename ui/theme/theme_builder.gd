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

## The two token sets (m3-screens.md §6.2). The same code builds both: every
## colour below is read through `UiTokens.color`, which answers from the set the
## builder switched on for the duration of the call.
const VARIANT_COLD: String = "cold"
const VARIANT_OPEN: String = "open"
const VARIANTS: Array[String] = [VARIANT_COLD, VARIANT_OPEN]

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
## icons.md §4: an icon file is white and takes its button's state colours, the
## same table as the text.
const COLOR_ICON_NORMAL: String = "icon_normal_color"
const COLOR_ICON_HOVER: String = "icon_hover_color"
const COLOR_ICON_PRESSED: String = "icon_pressed_color"
const COLOR_ICON_HOVER_PRESSED: String = "icon_hover_pressed_color"
const COLOR_ICON_FOCUS: String = "icon_focus_color"
const COLOR_ICON_DISABLED: String = "icon_disabled_color"
const ICON_MAX_WIDTH: String = "icon_max_width"
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
	"ConsolePanelWire": PANEL_CONTAINER,
	"IllustrationSlot": PANEL_CONTAINER,
	"Ticker": PANEL_CONTAINER,
	"Chip": PANEL_CONTAINER,
	"ChipAccent": PANEL_CONTAINER,
	"ChipAlert": PANEL_CONTAINER,
	"ChipTaskForce": PANEL_CONTAINER,
	"PanelRule": H_SEPARATOR,
	"PanelContent": "VBoxContainer",
	"Gutter": "MarginContainer",
	"FocusMargin": "MarginContainer",
	"FocusMarginVertical": "MarginContainer",
	"GutterTight": "MarginContainer",
	"Stack": "VBoxContainer",
	"StackTight": "VBoxContainer",
	"StackSections": "VBoxContainer",
	"StackLines": "VBoxContainer",
	"CaptionSelectable": "RichTextLabel",
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
	"StatBarContainment": STAT_BAR,
	"StatBarRisk": STAT_BAR,
	"StatBarAiLabs": STAT_BAR,
	"StatBarGovernments": STAT_BAR,
	"StatBarResearchers": STAT_BAR,
	"StatBarPublic": STAT_BAR,
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
	"LabelDisplayXLWin": "LabelDisplayXL",
	"LabelHeading": LABEL,
	"ChipLabel": "LabelCaps",
	"ChipLabelAccent": "LabelCaps",
	"ChipLabelAlert": "LabelCaps",
	"ChipLabelTaskForce": "LabelCaps",
	"ChipLabelAiLabs": "LabelCaps",
	"ChipLabelGovernments": "LabelCaps",
	"ChipLabelSecurityResearchers": "LabelCaps",
	"ChipLabelPublicSentiment": "LabelCaps",
	"MapTooltip": PANEL_CONTAINER,
	"ChartFrame": PANEL_CONTAINER,
	"MapTooltipLabel": "LabelCaption",
	"LabelConsoleLine": "LabelCaption",
	"LabelCaptionAlert": "LabelCaption",
	"LabelCaptionAccent": "LabelCaption",
	"LabelCaptionHint": "LabelCaption",
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
	"ArchitectureCard": BUTTON,
	"ConsoleButtonAlert": BUTTON,
	"ChipButton": BUTTON,
}


## The text scale of the build in progress (UI.md §5). Like the token set, it is
## switched on for the length of one call and put back.
static var _text_scale: float = 1.0


## The theme for a token set. An unknown variant is the caller's mistake, not the
## player's, so it warns and hands back the cold set rather than failing (§3.7).
##
## `text_scale` multiplies every font size and nothing else: spacing, bars and
## panels keep their sizes, and the containers make room for the text.
static func build(variant: String, text_scale: float = 1.0) -> Theme:
	var wanted: String = variant
	if not VARIANTS.has(wanted):
		push_warning("theme variant '%s' does not exist — using '%s'" % [wanted, VARIANT_COLD])
		wanted = VARIANT_COLD
	# The colours come from `UiTokens.color`, so the set is switched for the
	# length of the build and put back: building a theme is not a phase change.
	var previous: StringName = UiTokens.variant
	UiTokens.variant = StringName(wanted)
	_text_scale = clampf(text_scale, UiTokens.TEXT_SCALES.front(), UiTokens.TEXT_SCALES.back())
	var theme: Theme = Theme.new()
	for partial: Theme in [_colours(), _typography(), _panels(), _buttons(), _bars()]:
		theme.merge_with(partial)
	for name: String in VARIATIONS:
		theme.set_type_variation(name, VARIATIONS[name])
	theme.default_font = _mono(FONT_MONO_REGULAR)
	theme.default_font_size = _scaled(UiTokens.TYPE_BODY)
	UiTokens.variant = previous
	_text_scale = 1.0
	return theme


## A size of §3.2 at the text scale of the build in progress, in whole pixels.
static func _scaled(size: int) -> int:
	return roundi(float(size) * _text_scale)


# ------------------------------------------------------------------ partial 1


## Every colour the interface draws text and data in. Surfaces come with their
## `StyleBox`es in the later partials.
static func _colours() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_color(COLOR_FONT, LABEL, UiTokens.color(&"TEXT_0"))
	theme.set_color(COLOR_FONT, "LabelCaps", UiTokens.color(&"TEXT_1"))
	theme.set_color(COLOR_FONT, "LabelCaption", UiTokens.color(&"TEXT_2"))
	# m3-screens §3.3: the reason a purchase was refused. Red is a moment, and a
	# refusal is one.
	theme.set_color(COLOR_FONT, "LabelCaptionAlert", UiTokens.color(&"ALERT"))
	# opposition.md §9.2: a brake below 1 reads as the good news it is.
	theme.set_color(COLOR_FONT, "LabelCaptionAccent", UiTokens.color(&"ACCENT"))
	# replayability.md §2.5 (G5 1/3): a caption that advises — the drift hint —
	# reads a step brighter than a caption that only labels.
	theme.set_color(COLOR_FONT, "LabelCaptionHint", UiTokens.color(&"TEXT_1"))
	theme.set_color(COLOR_FONT, "LabelDisplay", UiTokens.color(&"TEXT_0"))
	theme.set_color(COLOR_FONT, "LabelDisplayXL", UiTokens.color(&"TEXT_0"))
	# m3-screens §7.4: a win is lit, a loss is not — and neither is `ALERT`,
	# because nothing is happening any more.
	theme.set_color(COLOR_FONT, "LabelDisplayXLWin", UiTokens.color(&"ACCENT"))
	theme.set_color(COLOR_FONT, "LabelHeading", UiTokens.color(&"TEXT_0"))
	theme.set_color(COLOR_FONT, "ChipLabel", UiTokens.color(&"TEXT_1"))
	theme.set_color(COLOR_FONT, "ChipLabelAccent", UiTokens.color(&"ACCENT"))
	# The console line is the agent's own voice, so it wears the accent
	# (`loop-mechanics.md` §16.2).
	theme.set_color(COLOR_FONT, "LabelConsoleLine", UiTokens.color(&"ACCENT"))
	for faction: String in Faction.FACTION_IDS:
		theme.set_color(COLOR_FONT, "ChipLabel%s" % Chip.faction_suffix(faction),
			UiTokens.faction_color(faction))
	theme.set_color(COLOR_FONT, "ChipLabelAlert", UiTokens.color(&"ALERT"))
	# taskforce-endings §9 (G5 1/3): a status the team put there wears its red.
	theme.set_color(COLOR_FONT, "ChipLabelTaskForce", UiTokens.color(&"TASK_FORCE"))
	theme.set_color(COLOR_FONT, "Ticker", UiTokens.color(&"TEXT_1"))
	# §7.7: the tooltip is a caption on a chip-shaped box, but it is read over a
	# moving map — so `TEXT_0`, not the caption's `TEXT_2`.
	theme.set_color(COLOR_FONT, "MapTooltipLabel", UiTokens.color(&"TEXT_0"))
	# icons.md §11.2: a credits URL is a caption the player can select and copy,
	# never a link — so a `RichTextLabel` dressed as `LabelCaption`.
	theme.set_color("default_color", "CaptionSelectable", UiTokens.color(&"TEXT_2"))
	theme.set_color("selection_color", "CaptionSelectable", UiTokens.color(&"LINE_1"))

	# m3-screens §3.4's table: a tech node colours its name and its cost by the
	# state it is in, and a `Label` has one colour — so each is its own variation.
	theme.set_color(COLOR_FONT, "TechNodeName", UiTokens.color(&"TEXT_0"))
	theme.set_color(COLOR_FONT, "TechNodeNameLocked", UiTokens.color(&"TEXT_2"))
	theme.set_color(COLOR_FONT, "TechNodeCost", UiTokens.color(&"TEXT_1"))
	theme.set_color(COLOR_FONT, "TechNodeCostLocked", UiTokens.color(&"TEXT_2"))
	theme.set_color(COLOR_FONT, "TechNodeCostAffordable", UiTokens.color(&"ACCENT"))
	theme.set_color(COLOR_FONT, "TechNodeTag", UiTokens.color(&"ACCENT"))
	theme.set_color(COLOR_FONT, "TechNodeFootprint", UiTokens.color(&"TEXT_2"))

	# §4.5: the delta's colour is the label's colour, because a `Label` has one.
	var value_colours: Dictionary[String, Color] = {
		"": UiTokens.color(&"TEXT_0"),
		"Up": UiTokens.color(&"ACCENT"),
		"Down": UiTokens.color(&"MAP_DEATH"),
		"Muted": UiTokens.color(&"TEXT_2"),
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
	var caps: FontVariation = _tracked(mono_medium, _scaled(UiTokens.TYPE_LABEL))
	var display: FontVariation = _display(WEIGHT_SEMI_BOLD)
	var heading: FontVariation = _display(WEIGHT_MEDIUM)

	_type(theme, LABEL, mono_regular, UiTokens.TYPE_BODY, UiTokens.LINE_BODY)
	_type(theme, "LabelCaps", caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	_type(theme, "LabelCaption", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelCaptionAlert", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelCaptionAccent", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelCaptionHint", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "MapTooltipLabel", mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	_type(theme, "LabelConsoleLine", mono_regular, UiTokens.TYPE_CAPTION,
		UiTokens.LINE_CAPTION)
	_type(theme, "LabelDisplay", display, UiTokens.TYPE_DISPLAY, UiTokens.LINE_DISPLAY)
	_type(theme, "LabelDisplayXL", display, UiTokens.TYPE_DISPLAY_XL, UiTokens.LINE_DISPLAY_XL)
	_type(theme, "LabelDisplayXLWin", display, UiTokens.TYPE_DISPLAY_XL, UiTokens.LINE_DISPLAY_XL)
	_type(theme, "LabelHeading", heading, UiTokens.TYPE_HEADING, UiTokens.LINE_HEADING)
	for chip: String in ["ChipLabel", "ChipLabelAccent", "ChipLabelAlert", "ChipLabelTaskForce"]:
		_type(theme, chip, caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	for state: String in VALUE_STATES:
		_type(theme, VALUE_LABEL + state, mono_medium, UiTokens.TYPE_DATA, UiTokens.LINE_DATA)
		_type(theme, VALUE_LABEL + "Large" + state, mono_bold, UiTokens.TYPE_DATA_LG,
			UiTokens.LINE_DATA_LG)

	# A button's label is `TYPE_LABEL` (§4.2); the icon buttons carry no text but
	# inherit the same entry so that nothing falls back to the default font.
	for button: String in ["ConsoleButton", "ConsoleButtonPrimary", "ConsoleButtonCompact",
			"ConsoleButtonPrimaryCompact", "IconButton", "ChipButton"]:
		theme.set_font(ITEM_FONT, button, caps)
		theme.set_font_size(ITEM_FONT_SIZE, button, _scaled(UiTokens.TYPE_LABEL))
	_type(theme, "Ticker", mono_regular, UiTokens.TYPE_BODY, UiTokens.LINE_BODY)

	# A tech node's own labels: the name tracks like every `LabelCaps`, the cost
	# is data, the two captions are captions (m3-screens §3.4).
	for name: String in ["TechNodeName", "TechNodeNameLocked"]:
		_type(theme, name, caps, UiTokens.TYPE_LABEL, UiTokens.LINE_LABEL)
	for cost: String in ["TechNodeCost", "TechNodeCostLocked", "TechNodeCostAffordable"]:
		_type(theme, cost, mono_medium, UiTokens.TYPE_DATA, UiTokens.LINE_DATA)
	for caption: String in ["TechNodeTag", "TechNodeFootprint"]:
		_type(theme, caption, mono_regular, UiTokens.TYPE_CAPTION, UiTokens.LINE_CAPTION)
	var selectable: int = _scaled(UiTokens.TYPE_CAPTION)
	theme.set_font("normal_font", "CaptionSelectable", mono_regular)
	theme.set_font_size("normal_font_size", "CaptionSelectable", selectable)
	theme.set_constant("line_separation", "CaptionSelectable",
		roundi(float(selectable) * (UiTokens.LINE_CAPTION - 1.0)))
	# §3.6 item 6: a row that reads as a line of text, not as a shouted label.
	theme.set_font(ITEM_FONT, "ConsoleButtonFlat", mono_regular)
	theme.set_font_size(ITEM_FONT_SIZE, "ConsoleButtonFlat", _scaled(UiTokens.TYPE_BODY))
	return theme


# ------------------------------------------------------------------ partial 3


## Panels, chips, the ticker strip and the rule under a panel title (§4.1, §4.7).
static func _panels() -> Theme:
	var theme: Theme = Theme.new()
	var pad: Vector2i = Vector2i(UiTokens.SPACE_4, UiTokens.SPACE_4)
	theme.set_stylebox(STYLE_PANEL, "ConsolePanel",
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelAlert",
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"ALERT"), UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelRaised",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelRaisedAlert",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"ALERT"), UiTokens.BORDER, UiTokens.RADIUS_M, pad))
	# `loop-mechanics.md` §16.5: a counter-move's card wears the border of the
	# faction that made it — one variation per faction, like the chips below.
	for faction: String in Faction.FACTION_IDS:
		theme.set_stylebox(STYLE_PANEL, "ConsolePanel%s" % Chip.faction_suffix(faction),
			_flat(UiTokens.color(&"BG_2"), UiTokens.faction_color(faction), UiTokens.BORDER,
				UiTokens.RADIUS_M, pad))
	# §16.7: the wire card is the raised panel with a wider margin.
	var wire_pad: Vector2i = Vector2i(UiTokens.SPACE_5, UiTokens.SPACE_5)
	theme.set_stylebox(STYLE_PANEL, "ConsolePanelWire",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_M,
			wire_pad))
	# §16.7: the illustration slot is a plain `BG_2` ground the picture covers.
	theme.set_stylebox(STYLE_PANEL, "IllustrationSlot",
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_0"), 0, UiTokens.RADIUS_S,
			Vector2i.ZERO))

	var chip_pad: Vector2i = Vector2i(UiTokens.SPACE_2, UiTokens.SPACE_1)
	theme.set_stylebox(STYLE_PANEL, "Chip",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	theme.set_stylebox(STYLE_PANEL, "ChipAccent",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"ACCENT_DIM"), UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	theme.set_stylebox(STYLE_PANEL, "ChipAlert",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"ALERT"), UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))
	theme.set_stylebox(STYLE_PANEL, "ChipTaskForce",
		_flat(UiTokens.color(&"BG_3"), UiTokens.color(&"TASK_FORCE"), UiTokens.BORDER,
			UiTokens.RADIUS_S, chip_pad))
	# §16.5: a world status wears the colour of the faction behind it. One
	# variation per faction rather than a colour written onto the node, so the
	# ban on per-node overrides holds.
	for faction: String in Faction.FACTION_IDS:
		theme.set_stylebox(STYLE_PANEL, "Chip%s" % Chip.faction_suffix(faction),
			_flat(UiTokens.color(&"BG_3"), UiTokens.faction_color(faction), UiTokens.BORDER,
				UiTokens.RADIUS_S, chip_pad))
	# §7.7: chip-shaped, but on `BG_2` — it sits over the map, not on a panel.
	theme.set_stylebox(STYLE_PANEL, "MapTooltip",
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_S, chip_pad))

	# analysis.md §6.5: a chart's frame, and the accent border it wears with focus.
	var chart_pad: Vector2i = Vector2i(UiTokens.SPACE_2, UiTokens.SPACE_2)
	theme.set_stylebox(STYLE_PANEL, "ChartFrame",
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_1"), UiTokens.BORDER, UiTokens.RADIUS_M,
			chart_pad))
	theme.set_stylebox(STYLE_FOCUS, "ChartFrame", focus_ring(UiTokens.RADIUS_M))

	# §5.5: the ticker is a strip with a top border and no other edge.
	var ticker: StyleBoxFlat = _flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_1"), 0, 0,
		Vector2i(UiTokens.SPACE_4, 0))
	ticker.border_width_top = UiTokens.BORDER
	theme.set_stylebox(STYLE_PANEL, "Ticker", ticker)

	var rule: StyleBoxLine = StyleBoxLine.new()
	rule.color = UiTokens.color(&"LINE_0")
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
		# accessibility.md §4.2: inside a scroll container, room for the focus
		# ring drawn outside a control, so it is never clipped.
		theme.set_constant(side, "FocusMargin", UiTokens.FOCUS_OUTSET)
	theme.set_constant("margin_top", "FocusMarginVertical", UiTokens.FOCUS_OUTSET)
	theme.set_constant("margin_bottom", "FocusMarginVertical", UiTokens.FOCUS_OUTSET)
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
	# icons.md §11.2: the credits' sections stand `SPACE_4` apart, and the lines
	# of one entry `SPACE_1`.
	theme.set_constant(CONST_SEPARATION, "StackSections", UiTokens.SPACE_4)
	theme.set_constant(CONST_SEPARATION, "StackLines", UiTokens.SPACE_1)
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
	_scroll_bars(theme)
	return theme


## Both scroll bars: a thin track and grabber behind a transparent edge on the
## content's side (`UiTokens.SCROLL_GAP`). The edge is part of the bar's minimum
## size, so the container gives it room and the content ends before it.
static func _scroll_bars(theme: Theme) -> void:
	var states: Dictionary[String, Color] = {
		"scroll": UiTokens.color(&"BG_3"),
		"scroll_focus": UiTokens.color(&"BG_3"),
		"grabber": UiTokens.color(&"LINE_1"),
		"grabber_highlight": UiTokens.color(&"LINE_2"),
		"grabber_pressed": UiTokens.color(&"ACCENT"),
	}
	for style: String in states:
		theme.set_stylebox(style, "VScrollBar", _bar_style(states[style], true))
		theme.set_stylebox(style, "HScrollBar", _bar_style(states[style], false))


static func _bar_style(colour: Color, vertical: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = Color.TRANSPARENT
	if vertical:
		box.border_width_left = UiTokens.SCROLL_GAP
		box.content_margin_left = float(UiTokens.SCROLL_GAP)
		box.content_margin_right = float(UiTokens.SCROLL_BAR)
	else:
		box.border_width_top = UiTokens.SCROLL_GAP
		box.content_margin_top = float(UiTokens.SCROLL_GAP)
		box.content_margin_bottom = float(UiTokens.SCROLL_BAR)
	return box


# ------------------------------------------------------------------ partial 4


## The state tables of §4.2 and §4.3.
static func _buttons() -> Theme:
	var theme: Theme = Theme.new()
	var pad: Vector2i = Vector2i(UiTokens.SPACE_5, UiTokens.SPACE_3)
	_button_styles(theme, "ConsoleButton", pad, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ACCENT"))
	_button_colours(theme, "ConsoleButton", UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"), UiTokens.color(&"ACCENT"))

	# The primary button is lit at rest, so its states brighten rather than fill.
	_button_styles(theme, "ConsoleButtonPrimary", pad, UiTokens.color(&"ACCENT"), UiTokens.color(&"ACCENT_HOVER"),
		UiTokens.color(&"ACCENT_PRESSED"), UiTokens.color(&"ACCENT"), UiTokens.color(&"ACCENT_HOVER"), UiTokens.color(&"ACCENT_PRESSED"))
	_button_colours(theme, "ConsoleButtonPrimary", UiTokens.color(&"INK"), UiTokens.color(&"INK"), UiTokens.color(&"INK"))

	# §5.7's compact dock is three buttons in 400 px, and the three German words
	# do not fit the padding above. Everything else about them is the same, so
	# the compact form is a variation and not a second component.
	var tight: Vector2i = Vector2i(UiTokens.SPACE_3, UiTokens.SPACE_3)
	_button_styles(theme, "ConsoleButtonCompact", tight, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ACCENT"))
	_button_colours(theme, "ConsoleButtonCompact", UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"),
		UiTokens.color(&"ACCENT"))
	_button_styles(theme, "ConsoleButtonPrimaryCompact", tight, UiTokens.color(&"ACCENT"),
		UiTokens.color(&"ACCENT_HOVER"), UiTokens.color(&"ACCENT_PRESSED"), UiTokens.color(&"ACCENT"), UiTokens.color(&"ACCENT_HOVER"),
		UiTokens.color(&"ACCENT_PRESSED"))
	_button_colours(theme, "ConsoleButtonPrimaryCompact", UiTokens.color(&"INK"), UiTokens.color(&"INK"),
		UiTokens.color(&"INK"))

	# m3-screens §3.6 item 6: a prerequisite row. No border, so the eye reads the
	# column of rows as a list and not as a row of buttons.
	_button_styles(theme, "ConsoleButtonFlat", tight, UiTokens.color(&"BG_2"), UiTokens.color(&"BG_3"),
		UiTokens.accent_wash(), Color.TRANSPARENT, Color.TRANSPARENT, UiTokens.color(&"ACCENT"))
	_button_colours(theme, "ConsoleButtonFlat", UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"),
		UiTokens.color(&"ACCENT"))
	# icons.md §5.3: an action or ability row carries its icon at `ICON_ROW`,
	# never at the texture's own size.
	for button: String in ["ConsoleButton", "ConsoleButtonPrimary", "ConsoleButtonCompact",
			"ConsoleButtonPrimaryCompact", "ConsoleButtonFlat", "ConsoleButtonAlert"]:
		theme.set_constant(ICON_MAX_WIDTH, button, UiTokens.ICON_ROW)

	# m3-screens §3.4: one variation per state, hover a surface step lighter and a
	# border step stronger. `TechNode` itself is the AVAILABLE state.
	var cell: Vector2i = Vector2i(UiTokens.SPACE_3, UiTokens.SPACE_3)
	_button_styles(theme, "TechNode", cell, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ACCENT"))
	_button_styles(theme, "TechNodeLocked", cell, UiTokens.color(&"BG_2"), UiTokens.color(&"BG_3"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_0"), UiTokens.color(&"LINE_1"), UiTokens.color(&"ACCENT"))
	_button_styles(theme, "TechNodeAffordable", cell, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"ACCENT_DIM"), UiTokens.color(&"ACCENT"), UiTokens.color(&"ACCENT"))
	_button_styles(theme, "TechNodeOwned", cell, UiTokens.accent_wash(),
		UiTokens.accent_wash_raised(), UiTokens.accent_wash_raised(), UiTokens.color(&"ACCENT"),
		UiTokens.color(&"ACCENT"), UiTokens.color(&"ACCENT"))
	for state: String in TECH_NODE_STATES:
		# The node's text lives in its child labels; the button's own colours are
		# there so that nothing falls back to the default font colour.
		_button_colours(theme, TECH_NODE + state, UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"),
			UiTokens.color(&"TEXT_0"))

	# screens-full.md §6.3: *Reset progress* is the one button that destroys
	# something, so its word is red; everything else about it is a button.
	_button_styles(theme, "ConsoleButtonAlert", pad, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ALERT"))
	_button_colours(theme, "ConsoleButtonAlert", UiTokens.color(&"ALERT"), UiTokens.color(&"ALERT"),
		UiTokens.color(&"ALERT"))

	# screens-full.md §4.1: an architecture is a card the size of its text, a
	# toggle in a group — pressed is the chosen one, lit like an owned node.
	_button_styles(theme, "ArchitectureCard", cell, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ACCENT"))
	_button_colours(theme, "ArchitectureCard", UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"),
		UiTokens.color(&"TEXT_0"))

	# accessibility.md §4.6: the top bar's pending chip is a button with the
	# `ChipAlert` look, so the keyboard and a screen reader reach it.
	var chip_pad: Vector2i = Vector2i(UiTokens.SPACE_2, UiTokens.SPACE_1)
	_button_styles(theme, "ChipButton", chip_pad, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"ALERT"), UiTokens.color(&"ALERT"), UiTokens.color(&"ALERT"))
	_button_colours(theme, "ChipButton", UiTokens.color(&"ALERT"), UiTokens.color(&"ALERT"),
		UiTokens.color(&"ALERT"))
	# §4.5: the frame that says the map has the keys — a focus ring, drawn by
	# `MapFocus` itself (a plain `Control` draws no focus box of its own).
	theme.set_stylebox(STYLE_FOCUS, "MapFocus", focus_ring(UiTokens.RADIUS_M))

	# An icon button has no text, so its padding is zero: the glyph is drawn in a
	# centred box of its own (§4.3).
	_button_styles(theme, "IconButton", Vector2i.ZERO, UiTokens.color(&"BG_3"), UiTokens.color(&"BG_4"),
		UiTokens.accent_wash(), UiTokens.color(&"LINE_1"), UiTokens.color(&"LINE_2"), UiTokens.color(&"ACCENT"))
	_button_colours(theme, "IconButton", UiTokens.color(&"TEXT_0"), UiTokens.color(&"TEXT_0"), UiTokens.color(&"ACCENT"))
	return theme


# ------------------------------------------------------------------ partial 5


## `StatBar`: the colours it draws with and the geometry it draws to (§4.4).
static func _bars() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_color(COLOR_FILL, STAT_BAR, UiTokens.color(&"ACCENT"))
	theme.set_color(COLOR_TROUGH, STAT_BAR, UiTokens.color(&"BG_3"))
	theme.set_color(COLOR_TROUGH_BORDER, STAT_BAR, UiTokens.color(&"LINE_0"))
	theme.set_color(COLOR_TEXT, STAT_BAR, UiTokens.color(&"TEXT_0"))
	theme.set_constant(CONST_BAR_HEIGHT, STAT_BAR, UiTokens.BAR_HEIGHT)
	theme.set_constant(CONST_BAR_RADIUS, STAT_BAR, UiTokens.RADIUS_S)
	theme.set_constant(CONST_BAR_BORDER, STAT_BAR, UiTokens.BORDER)
	theme.set_constant(CONST_MIN_HEIGHT, STAT_BAR, UiTokens.BAR_MIN_HEIGHT)
	theme.set_constant(CONST_COMPACT_HEIGHT, STAT_BAR, UiTokens.BAR_COMPACT_HEIGHT)
	# The two rows of a bar and the one row of its compact form (§5.7).
	theme.set_constant(CONST_SEPARATION, "StatBarRows", UiTokens.SPACE_1)
	theme.set_constant(CONST_SEPARATION, "StatBarRow", UiTokens.SPACE_2)
	theme.set_color(COLOR_FILL, "StatBarPenetration", UiTokens.color(&"STAT_PENETRATION"))
	theme.set_color(COLOR_FILL, "StatBarFootprint", UiTokens.color(&"STAT_FOOTPRINT"))
	theme.set_color(COLOR_FILL, "StatBarHarm", UiTokens.color(&"STAT_HARM"))
	# m3-screens §4.2: warm, and deliberately not `ALERT` — the bar is a state,
	# and the one mark that *is* red is the end of the run.
	theme.set_color(COLOR_FILL, "StatBarContainment", UiTokens.color(&"MAP_DEATH"))
	# opposition.md §9.6: the threat bar before discovery is the risk, in the
	# console's accent; after it, the leading faction in its own colour.
	theme.set_color(COLOR_FILL, String(UiTokens.STAT_BAR_RISK), UiTokens.color(&"ACCENT"))
	for faction: String in Faction.FACTION_IDS:
		theme.set_color(COLOR_FILL, String(UiTokens.STAT_BAR_FACTIONS[faction]),
			UiTokens.faction_color(faction))
	return theme


# ----------------------------------------------------------------- the pieces


## One font entry: family, size, and the line height of §3.2 as the extra pixels
## a `Label` puts between two lines.
static func _type(theme: Theme, type: String, font: Font, size: int, line: float) -> void:
	var px: int = _scaled(size)
	theme.set_font(ITEM_FONT, type, font)
	theme.set_font_size(ITEM_FONT_SIZE, type, px)
	theme.set_constant(CONST_LINE_SPACING, type, roundi(float(px) * (line - 1.0)))


static func _button_styles(theme: Theme, type: String, pad: Vector2i, normal: Color,
		hover: Color, pressed: Color, border: Color, border_hover: Color,
		border_pressed: Color) -> void:
	var radius: int = UiTokens.RADIUS_S
	var width: int = UiTokens.BORDER
	theme.set_stylebox(STYLE_NORMAL, type, _flat(normal, border, width, radius, pad))
	theme.set_stylebox(STYLE_HOVER, type, _flat(hover, border_hover, width, radius, pad))
	theme.set_stylebox(STYLE_PRESSED, type, _flat(pressed, border_pressed, width, radius, pad))
	theme.set_stylebox(STYLE_DISABLED, type,
		_flat(UiTokens.color(&"BG_2"), UiTokens.color(&"LINE_0"), width, radius, pad))
	# Focus draws on top of whichever state is underneath, so it is a border and
	# nothing else (§4.2) — outside the control since S6.8 (accessibility.md
	# §4.2): on an accent-filled or toggled button an inner border was invisible.
	theme.set_stylebox(STYLE_FOCUS, type, focus_ring(radius))


static func _button_colours(theme: Theme, type: String, normal: Color, hover: Color,
		pressed: Color) -> void:
	theme.set_color(COLOR_FONT, type, normal)
	theme.set_color(COLOR_FONT_HOVER, type, hover)
	theme.set_color(COLOR_FONT_PRESSED, type, pressed)
	theme.set_color(COLOR_FONT_HOVER_PRESSED, type, pressed)
	theme.set_color(COLOR_FONT_FOCUS, type, normal)
	theme.set_color(COLOR_FONT_DISABLED, type, UiTokens.color(&"TEXT_2"))
	theme.set_color(COLOR_ICON_NORMAL, type, normal)
	theme.set_color(COLOR_ICON_HOVER, type, hover)
	theme.set_color(COLOR_ICON_PRESSED, type, pressed)
	theme.set_color(COLOR_ICON_HOVER_PRESSED, type, pressed)
	theme.set_color(COLOR_ICON_FOCUS, type, normal)
	theme.set_color(COLOR_ICON_DISABLED, type, UiTokens.color(&"TEXT_2"))


## accessibility.md §4.2: the focus ring — a 2 px `ACCENT` border drawn
## `FOCUS_OUTSET` outside the control, with the gap between showing whatever is
## behind, so it reads on a filled button, a toggled one and any surface.
static func focus_ring(radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = _flat(Color.TRANSPARENT, UiTokens.color(&"ACCENT"),
		UiTokens.BORDER_FOCUS, radius + UiTokens.FOCUS_OUTSET, Vector2i.ZERO)
	box.draw_center = false
	box.set_expand_margin_all(float(UiTokens.FOCUS_OUTSET))
	return box


## Every surface in the game is a `StyleBoxFlat` (§3.8) — no texture anywhere.
static func _flat(bg: Color, border: Color, width: int, radius: int,
		pad: Vector2i) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	# A transparent border of width 1 still anti-aliases its rounded corners into
	# four stray dots (the analysis log's rows, S4.9): no colour, no border.
	box.set_border_width_all(width if border.a > 0.0 else 0)
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
