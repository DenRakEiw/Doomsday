class_name UiTokens
extends RefCounted
## Every design value of spec ui-foundation.md §3, as typed constants.
##
## This is the single source: nothing else in `ui/` or `game/` may contain a
## colour, a font size or a duration (CLAUDE.md, *Constants*). A literal outside
## this file is a defect — `ThemeBuilder` (S2.4) reads the theme's values from
## here, the map shader takes its colours as uniforms set from here, and every
## tween takes its time from `duration`.
##
## Never instantiated; it is a namespace of constants.

## Where `reduced_motion` looks for the setting, and what it reads there.
const SETTINGS_PATH: NodePath = ^"/root/Settings"
const SETTING_REDUCED_MOTION: StringName = &"reduced_motion"

## Built on first use by `ramp_texture`, then shared by everything that ramps.
static var _ramp: GradientTexture1D = null


# ----------------------------------------------------------- §3.1 ground and chrome


const BG_0: Color = Color("#07090C")
const BG_1: Color = Color("#0B1016")
const BG_2: Color = Color("#101820")
const BG_3: Color = Color("#16212B")
const BG_4: Color = Color("#1C2A36")

const LINE_0: Color = Color("#1F2C38")
const LINE_1: Color = Color("#2C3D4C")
const LINE_2: Color = Color("#4A6478")

const TEXT_0: Color = Color("#DCE6EE")
const TEXT_1: Color = Color("#93A6B5")
## 3.6 : 1 — never for essential text.
const TEXT_2: Color = Color("#5E7282")

## The console's own voice: focus, primary action, active state, links, anomalies.
const ACCENT: Color = Color("#6FE3FF")
const ACCENT_DIM: Color = Color("#2E6E80")
## The two lit states of a primary button (§4.2). They are colours, so they live
## here and not in the theme builder.
const ACCENT_HOVER: Color = Color("#8FEAFF")
const ACCENT_PRESSED: Color = Color("#4FCBE8")
## Reserved for "something is happening right now"; never a permanent fill.
const ALERT: Color = Color("#FF3B3B")
## Text on an accent or alert fill.
const INK: Color = Color("#07090C")


# ------------------------------------------------- §3.1 data colours (M4, reserved)


## Okabe–Ito without black. `CAT_YELLOW` is the only one still free: it sits at
## the top of the ramp, and a faction colour there would read as a magnitude.
const CAT_ORANGE: Color = Color("#E69F00")
const CAT_SKY: Color = Color("#56B4E9")
const CAT_GREEN: Color = Color("#009E73")
const CAT_YELLOW: Color = Color("#F0E442")
const CAT_PINK: Color = Color("#CC79A7")

## `loop-mechanics.md` §16.12: one colour per faction, shared by S4.2's status
## rings, the map's border rule and D4.2's threat bar — so that a colour means
## the same faction wherever it appears.
const FACTION_AI_LABS: Color = CAT_SKY
const FACTION_GOVERNMENTS: Color = CAT_ORANGE
const FACTION_RESEARCHERS: Color = CAT_GREEN
const FACTION_PUBLIC: Color = CAT_PINK
## Faction id → its token, in `Faction.FACTION_IDS` order.
const FACTION_TOKENS: Dictionary[String, StringName] = {
	"ai_labs": &"FACTION_AI_LABS",
	"governments": &"FACTION_GOVERNMENTS",
	"security_researchers": &"FACTION_RESEARCHERS",
	"public_sentiment": &"FACTION_PUBLIC",
}


# ---------------------------------------------------------- §3.1 magnitude ramp


## Viridis truncated to its upper half, five stops, interpolated in sRGB.
const RAMP_COLORS: Array[Color] = [
	Color("#208F8C"), Color("#35B779"), Color("#6DCD59"), Color("#B5DE2B"),
	Color("#FDE725"),
]
const RAMP_OFFSETS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const RAMP_WIDTH: int = 256


# ------------------------------------------------------------- §3.1 map colours


const MAP_LAND: Color = Color("#1A2530")
const MAP_DARK: Color = Color("#0E1318")
const MAP_BORDER: Color = Color("#3A4B5C")
const MAP_BORDER_DARK: Color = Color("#1F2C38")
## The × at a dark region's anchor — `TEXT_2`, because in the border's colour it
## was invisible (G2).
const MAP_DARK_MARK: Color = Color("#5E7282")
## How much of the ramp's colour covers the land under an overlay. Not a colour:
## the shader takes it as a uniform like every other token (§7.3). At 0.85 a
## half-taken world outshone the HUD (G2).
const MAP_OVERLAY_MIX: float = 0.70
## A multiplier on the region's colour, not a colour.
const MAP_HOVER_GAIN: float = 1.15
const MAP_SELECT: Color = Color("#FFFFFF")
## The population overlay's end colour (alive share → 0).
const MAP_DEATH: Color = Color("#FF8C6B")

const STAT_PENETRATION: Color = Color("#B5DE2B")
const STAT_FOOTPRINT: Color = Color("#6FE3FF")
## Warm, and deliberately not `ALERT`: red means "now", a bar is a state.
const STAT_HARM: Color = Color("#FF8C6B")

const BACKDROP_GRID: Color = Color("#121A22")
const BACKDROP_STAR: Color = Color("#2C3D4C")


# ------------------------------------------------------ §6.2 the token sets


## The two palettes the game has. Everything above is the **cold** set; `OPEN`
## holds the rows m3-screens.md §6.2 changes for the Open phase, and nothing
## else — the ramp, the categorical colours, `ALERT`, `MAP_SELECT`, `MAP_DEATH`
## and the stat colours stay as they are in both, because data has to keep
## reading the same and red has to keep meaning "now".
const VARIANT_COLD: StringName = &"cold"
const VARIANT_OPEN: StringName = &"open"

const OPEN: Dictionary[StringName, Color] = {
	&"BG_0": Color("#0C0608"),
	&"BG_1": Color("#150A0D"),
	&"BG_2": Color("#1E1014"),
	&"BG_3": Color("#28161B"),
	&"BG_4": Color("#331C22"),
	&"LINE_0": Color("#33202A"),
	&"LINE_1": Color("#4A2E38"),
	&"LINE_2": Color("#70485A"),
	&"TEXT_0": Color("#F2E4E1"),
	&"TEXT_1": Color("#C9A29E"),
	&"TEXT_2": Color("#87646A"),
	&"ACCENT": Color("#FFB35C"),
	&"ACCENT_DIM": Color("#8F5E2A"),
	&"ACCENT_HOVER": Color("#FFC985"),
	&"ACCENT_PRESSED": Color("#E39A46"),
	&"INK": Color("#0C0608"),
	&"MAP_LAND": Color("#2C1B22"),
	&"MAP_DARK": Color("#120A0D"),
	&"MAP_BORDER": Color("#5C3C48"),
	&"MAP_BORDER_DARK": Color("#33202A"),
	&"MAP_DARK_MARK": Color("#87646A"),
	&"BACKDROP_GRID": Color("#1F1116"),
	&"BACKDROP_STAR": Color("#4A2E38"),
}

## Which set `color()` answers from. The session sets it when the phase turns
## Open and back to cold for a new run; everything that draws asks `color()` and
## redraws on `EventBus.theme_variant_changed`.
static var variant: StringName = VARIANT_COLD

## The cold constants by name, read once out of the script itself so that the
## table above stays the only place a colour is written.
static var _cold: Dictionary[StringName, Color] = {}


## The value of a colour token in the set that is active. An unknown token is a
## programming error and comes back as magenta rather than as a crash.
static func color(token: StringName) -> Color:
	if variant == VARIANT_OPEN and OPEN.has(token):
		return OPEN[token]
	if _cold.is_empty():
		_read_cold()
	if not _cold.has(token):
		push_error("unknown colour token \"%s\"" % token)
		return Color.MAGENTA
	return _cold[token]


static func _read_cold() -> void:
	var script: GDScript = UiTokens
	for name: String in script.get_script_constant_map():
		var value: Variant = script.get_script_constant_map()[name]
		if typeof(value) == TYPE_COLOR:
			_cold[StringName(name)] = value


# ---------------------------------------------------------------- §3.2 typography


const FONT_MONO: String = "JetBrains Mono"
const FONT_DISPLAY: String = "Space Grotesk"

## `[family, weight, size, line height, tracking in em, uppercase]` per §3.2.
## Read by `ThemeBuilder` (S2.4); the sizes are at the 1920×1080 base.
const TYPE_DISPLAY_XL: int = 40
const TYPE_DISPLAY: int = 28
const TYPE_HEADING: int = 20
const TYPE_BODY: int = 16
const TYPE_DATA: int = 16
const TYPE_DATA_LG: int = 24
const TYPE_LABEL: int = 13
const TYPE_CAPTION: int = 12

const LINE_DISPLAY_XL: float = 1.0
const LINE_DISPLAY: float = 1.05
const LINE_HEADING: float = 1.15
const LINE_BODY: float = 1.4
const LINE_DATA: float = 1.2
const LINE_DATA_LG: float = 1.0
const LINE_LABEL: float = 1.2
const LINE_CAPTION: float = 1.3

## Only `TYPE_LABEL` tracks, and only it is uppercased — by the component, never
## in the string table.
const TRACKING_LABEL: float = 0.08
## UI.md §5: the text scales the settings offer, smallest first. The theme
## multiplies every font size by one of them; the layout is tested at the last.
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]


# ------------------------------------------------ §3.3 spacing, radii, borders


const SPACE_1: int = 4
const SPACE_2: int = 8
const SPACE_3: int = 12
const SPACE_4: int = 16
const SPACE_5: int = 24
const SPACE_6: int = 32

## Between a HUD block and the viewport edge, after the safe area.
const GUTTER: int = 16
const RADIUS_S: int = 2
const RADIUS_M: int = 4
const BORDER: int = 1
const BORDER_FOCUS: int = 2
## The minimum size of anything tappable, on every platform. One logical pixel is
## one dp (§6.1), so this is 48 dp everywhere.
const HIT_MIN: int = 48
## A scroll bar keeps this gap from the content it scrolls, and is this wide. Godot
## puts the bar flush against the content, so text touching the bar read as text
## running under it (S4.2, S4.9); the gap is a transparent edge of the bar itself,
## which makes it one rule for every scroll container.
const SCROLL_GAP: int = 8
const SCROLL_BAR: int = 6

## §4.4's geometry for `StatBar`: the bar itself, the full row, and the one-line
## compact row of §5.7. Sizes rather than spacing, so they stand apart from the
## scale above.
const BAR_HEIGHT: int = 12
const BAR_MIN_HEIGHT: int = 44
const BAR_COMPACT_HEIGHT: int = 28
## The glyph box an `IconButton` draws in, and its stroke (§4.3).
const GLYPH_BOX: int = 24
const GLYPH_STROKE: float = 2.0


# ------------------------------------------------------------- §5 HUD geometry


## Below this the interface lays itself out compact (§5.7). One logical pixel is
## one dp (§6.1), so the same number is the rule on every device.
const COMPACT_WIDTH: int = 1100

## The heights of §5.7's table: the strips the HUD puts against the edges, and
## the two forms of the top bar.
const TOP_BAR_HEIGHT: int = 56
const TOP_BAR_ROW_HEIGHT: int = 48
const STAT_ROW_HEIGHT: int = 64
const STAT_ROW_COMPACT_HEIGHT: int = 84
const TICKER_HEIGHT: int = 40
## ticker.md §4.5: a line that stands still gets two rows to stand in.
const TICKER_STATIC_HEIGHT: int = 64

## §5.5: a dock button is bigger than `HIT_MIN` because it is a destination, not
## a control.
const DOCK_BUTTON_HEIGHT: int = 56
const DOCK_BUTTON_WIDTH: int = 200
## §5.2: the compute cell keeps its width while the number under it changes.
const CELL_MIN_WIDTH: int = 200

## §5.6's attribute pips: four squares of this size, this far apart.
const PIP_SIZE: int = 10
const PIP_GAP: int = 4

## §5.3: footprint and harm have no natural 100 %, so the bar fills against a
## presentation maximum while the label reads the raw number.
const FOOTPRINT_BAR_MAX: float = 20.0
const HARM_BAR_MAX: float = 8.0


# ------------------------------------------------------- §6.3 M3 geometry


## m3-screens §3.2: one cell of a tree grid, in the wide and the compact layout.
const TECH_CELL: Vector2 = Vector2(200, 96)
const TECH_CELL_COMPACT: Vector2 = Vector2(160, 88)
## §3.5: the width of a prerequisite line, and of the selected node's own.
const TECH_LINE: float = 2.0
const TECH_LINE_SELECTED: float = 3.0
## Dash on, dash off.
const TECH_DASH: Vector2 = Vector2(8, 6)

## §10.4: how much of the scene behind a modal the scrim keeps.
const SCRIM_ALPHA: float = 0.85
## §5, §7.3, §7.4: a modal never grows wider than this.
const MODAL_MAX_WIDTH: int = 560
## `loop-mechanics.md` §16.12: the wire card's own width, the console line's
## pace, and the geometry of the markers M4 adds.
const WIRE_MAX_WIDTH: int = 840
const CONSOLE_LINE_MS: int = 4000
const CONSOLE_QUEUE_MAX: int = 3
const MOTION_SCOPE_FLASH: int = 1500
const MARKER_ROW_OFFSET: int = 18
const MARKER_EVENT_OFFSET: Vector2 = Vector2(-18.0, -18.0)
const STATUS_RING_RADIUS: float = 14.0
const STATUS_RING_STEP: float = 5.0
## §16.3.2: a fleet is drawn larger than the rest of the row.
const ASSET_GLYPH_LEAD: float = 16.0
const ASSET_GLYPH: float = 12.0
## m3-screens §5: the red wash of the discovery moment, and how long it lasts.
const ALERT_FLASH_ALPHA: float = 0.25
## m3-screens §7.4: how long the last frame is left alone before the results
## cover it, and §7.5's autosave cadence in days.
const RESULTS_DELAY: int = 800
const AUTOSAVE_INTERVAL_DAYS: int = 7

## opposition.md §9.6: the discovery risk that fills the threat bar before
## discovery, and the last days of starving that turn the chip red.
const RISK_BAR_MAX: float = 0.02
const STARVING_ALERT_DAYS: int = 5
## §9.1: the size of the faction glyph beside the threat bar's label.
const FACTION_GLYPH: float = 16.0
## §9.6: the `StatBar` variation of the risk face and of each faction's face.
const STAT_BAR_RISK: StringName = &"StatBarRisk"
const STAT_BAR_FACTIONS: Dictionary[String, StringName] = {
	"ai_labs": &"StatBarAiLabs",
	"governments": &"StatBarGovernments",
	"security_researchers": &"StatBarResearchers",
	"public_sentiment": &"StatBarPublic",
}

## analysis.md §10: the Analysis sheet, its charts, the timeline strip and the
## log. Chart geometry is drawn, so it lives here rather than in the theme.
const ANALYSIS_HEIGHT_SHARE: float = 0.55
const ANALYSIS_HEIGHT_SHARE_COMPACT: float = 0.85
const CHART_MIN_HEIGHT: int = 200
const CHART_MIN_HEIGHT_COMPACT: int = 160
const CHART_MIN_HEIGHT_SMALL: int = 120
const CHART_TITLE_H: float = 24.0
const CHART_LEGEND_H: float = 20.0
const CHART_AXIS_W: float = 56.0
const CHART_LABEL_W: float = 80.0
const CHART_AXIS_H: float = 20.0
const CHART_LINE_W: float = 2.0
const CHART_MARK_R: float = 4.0
const CHART_RING_W: float = 2.0
const CHART_AREA_ALPHA: float = 0.10
const CHART_STACK_ALPHA: float = 0.6
const CHART_TICK_MIN_PX: float = 80.0
const CHART_X_TICKS: Array[int] = [10, 25, 50, 100, 250, 500, 1000]
const MIN_SPAN_DAYS: int = 30
const TABLE_ROWS: int = 16
const STRIP_H: int = 28
const STRIP_SLOT: float = 12.0
## Every row of the log is a hit target, the plain ones too: rows of two heights
## read as two lists (S4.9).
const LOG_ROW_MIN_H: int = HIT_MIN
const LOG_DAY_W: int = 56
## §9: the colour of each entity, fixed and never by position — `single` for any
## one-series chart.
const SERIES: Dictionary[StringName, StringName] = {
	&"single": &"ACCENT",
	&"reached": &"STAT_PENETRATION",
	&"controlled": &"ACCENT",
	&"dark": &"MAP_DEATH",
	&"alive": &"TEXT_1",
	&"dead": &"MAP_DEATH",
}


## §4.2: how tall one containment track is, and §9.1's strip.
const TRACK_HEIGHT: int = 72
const STATUS_STRIP_HEIGHT: int = 56

## §3.6, §9.2: how much of the screen a sheet takes. The region panel keeps its
## own 0.5 (`SlidePanel.HEIGHT_SHARE`).
const SHEET_HEIGHT_RATIO: float = 0.55


# -------------------------------------------------------------------- §3.4 motion


## Milliseconds. Never used raw — `duration` turns a token into tween seconds and
## answers 0 while reduced motion is on.
const MOTION_HOVER: int = 80
const MOTION_QUICK: int = 120
const MOTION_PANEL: int = 200
const MOTION_BAR: int = 250
const MOTION_FLASH: int = 400
## M3, reserved.
const MOTION_MODAL: int = 160
## m3-screens §5: the discovery flash, slower than anything else because it is
## the one moment the game stops for.
const MOTION_ALERT: int = 600
## m3-screens §6.5: one full breath of the Boxed pulse.
const PULSE_PERIOD: int = 1600
const ANOMALY_PULSE_PERIOD: int = 1200
## How long a static ticker item stays before the next one replaces it (§5.5),
## plus this much per character of it (ticker.md §4.5): an 80-character line
## stands 8.8 s. It is a timeout, not a movement: reduced motion shortens
## nothing about it.
const TICKER_STATIC_PERIOD: int = 4000
const TICKER_STATIC_PER_CHAR: int = 60

const MS_PER_SECOND: float = 1000.0

## Pixels per second, not milliseconds: these are speeds, and reduced motion
## stops the movement rather than shortening it.
const LINK_FLOW_SPEED: float = 60.0
const TICKER_SPEED: float = 80.0
const TICKER_SPEED_COMPACT: float = 60.0


# --------------------------------------------------------------- derived values


## How much accent a pressed `ConsoleButton` takes over its resting surface
## (§4.2, "`ACCENT` at 20 % over `BG_3`").
const PRESSED_WASH: float = 0.2


## The pressed surface of §4.2 — a blend of two tokens, which a `const` cannot
## hold. Everything that needs the colour asks here, so it still has one source.
static func accent_wash() -> Color:
	return color(&"BG_3").lerp(color(&"ACCENT"), PRESSED_WASH)


## The same wash one surface step lighter, for the hover state of something that
## is already washed (an owned tech node, m3-screens §3.4).
static func accent_wash_raised() -> Color:
	return color(&"BG_4").lerp(color(&"ACCENT"), PRESSED_WASH)


## A motion token as tween seconds, or 0 while `Settings.reduced_motion` is on.
## Every component asks here; nobody reads the setting by hand.
##
## The autoload is looked up by path rather than named: a script that names one
## cannot be compiled outside the tree (PROGRESS.md, *Known issues*), and
## `tools/build_theme.gd` has to be able to load this file.
static func duration(motion_ms: int) -> float:
	if reduced_motion():
		return 0.0
	return seconds(motion_ms)


## A motion token as plain seconds, whatever the setting says — for a timeout
## that still has to elapse when nothing moves (§5.5's static ticker).
static func seconds(motion_ms: int) -> float:
	return float(motion_ms) / MS_PER_SECOND


## Whether motion is off right now. False wherever there is no `Settings` — a
## test or a tool has no autoloads and animates nothing.
static func reduced_motion() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var settings: Node = tree.root.get_node_or_null(SETTINGS_PATH)
	return settings != null and bool(settings.get(SETTING_REDUCED_MOTION))


## The threat bar's variation for a faction (opposition.md §9.6); the plain
## containment bar for an id that is no faction.
static func stat_bar_variation(faction_id: String) -> StringName:
	return STAT_BAR_FACTIONS.get(faction_id, &"StatBarContainment")


## The colour of a chart entity (§9's table).
static func series_color(entity: StringName) -> Color:
	return color(SERIES.get(entity, &"ACCENT"))


## A share of the magnitude ramp (§9: the society stages), 0…1.
static func ramp_color(share: float) -> Color:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array(RAMP_OFFSETS)
	gradient.colors = PackedColorArray(RAMP_COLORS)
	return gradient.sample(clampf(share, 0.0, 1.0))


## The colour a faction is drawn in. An unknown id — a world status that no
## faction owns — takes the console's own accent (§16.3.1).
static func faction_color(faction: String) -> Color:
	if not FACTION_TOKENS.has(faction):
		return color(&"ACCENT")
	return color(FACTION_TOKENS[faction])


## The §3.1 ramp as a 256-wide gradient, built once and shared by the map shader
## and the stat bars. `ThemeBuilder` (S2.4) hands out this same texture.
static func ramp_texture() -> GradientTexture1D:
	if _ramp == null:
		var gradient: Gradient = Gradient.new()
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
		gradient.offsets = PackedFloat32Array(RAMP_OFFSETS)
		gradient.colors = PackedColorArray(RAMP_COLORS)
		var texture: GradientTexture1D = GradientTexture1D.new()
		texture.gradient = gradient
		texture.width = RAMP_WIDTH
		# The gradient is authored in sRGB and the map shader compares it against
		# sRGB tokens, so no conversion happens on the way in.
		texture.use_hdr = false
		_ramp = texture
	return _ramp
