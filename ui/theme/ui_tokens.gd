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


## Okabe–Ito without black. M2 uses none of them — they are tokens now so that
## nothing in M2 accidentally takes one.
const CAT_ORANGE: Color = Color("#E69F00")
const CAT_SKY: Color = Color("#56B4E9")
const CAT_GREEN: Color = Color("#009E73")
const CAT_YELLOW: Color = Color("#F0E442")
const CAT_PINK: Color = Color("#CC79A7")


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

## §4.4's geometry for `StatBar`: the bar itself, the full row, and the one-line
## compact row of §5.7. Sizes rather than spacing, so they stand apart from the
## scale above.
const BAR_HEIGHT: int = 12
const BAR_MIN_HEIGHT: int = 44
const BAR_COMPACT_HEIGHT: int = 28
## The glyph box an `IconButton` draws in, and its stroke (§4.3).
const GLYPH_BOX: int = 24
const GLYPH_STROKE: float = 2.0


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
const ANOMALY_PULSE_PERIOD: int = 1200

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
	return BG_3.lerp(ACCENT, PRESSED_WASH)


## A motion token as tween seconds, or 0 while `Settings.reduced_motion` is on.
## Every component asks here; nobody reads the setting by hand.
##
## The autoload is looked up by path rather than named: a script that names one
## cannot be compiled outside the tree (PROGRESS.md, *Known issues*), and
## `tools/build_theme.gd` has to be able to load this file.
static func duration(motion_ms: int) -> float:
	if reduced_motion():
		return 0.0
	return float(motion_ms) / 1000.0


## Whether motion is off right now. False wherever there is no `Settings` — a
## test or a tool has no autoloads and animates nothing.
static func reduced_motion() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var settings: Node = tree.root.get_node_or_null(SETTINGS_PATH)
	return settings != null and bool(settings.get(SETTING_REDUCED_MOTION))


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
