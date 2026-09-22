extends Control
## Every component of spec ui-foundation.md §4 in every state (§4.8).
##
## This is the visual regression target for all later interface work: if a token
## or a theme rule changes, this is the screen that is compared. It is built in
## code rather than authored so that a new state is one line and so that every
## label goes through the real string table — the German lengths are the point.
##
## A development tool: it ships in no build, it is never reached from the game,
## and its section titles are English on purpose. Run it directly:
##
##     "$GODOT" --path . res://ui/dev/gallery.tscn
##
## Scene-specific, so no `class_name`.

## Real keys from `data/loc/strings.csv` — §4.8 forbids lorem ipsum, because a
## component that fits "Close" and not "Schließen" is broken and has to show it.
const KEY_CLOSE: String = "UI_COMMON_CLOSE"
const KEY_COLLECT: String = "UI_REGION_COLLECT"
const KEY_NOT_YET: String = "UI_DOCK_NOT_YET"
const KEY_TICKER_IDLE: String = "UI_TICKER_IDLE"
const KEY_DARK: String = "UI_REGION_STATE_DARK"
const KEY_PROFILE: String = "UI_REGION_ATTRIBUTES"
const DOCK_KEYS: Array[String] = ["UI_DOCK_CAPABILITIES", "UI_DOCK_CONTAINMENT",
	"UI_DOCK_ANALYSIS"]
const STAT_KEYS: Array[String] = ["UI_TERM_PENETRATION", "UI_TERM_FOOTPRINT", "UI_TERM_HARM"]
const STAT_VARIATIONS: Array[String] = ["StatBarPenetration", "StatBarFootprint",
	"StatBarHarm"]
const CHIP_KEYS: Array[String] = ["UI_PHASE_BOXED", "UI_PHASE_COVERT", "UI_REGION_AIR_GAPPED"]
const SPEED_KEYS: Array[String] = ["UI_HUD_SPEED_PAUSE", "UI_HUD_SPEED_1", "UI_HUD_SPEED_2",
	"UI_HUD_SPEED_4"]

## Sample numbers, chosen so that every `Format.Kind` shows its separators.
const SAMPLE_COMPUTE: float = 1284.5
const SAMPLE_DELTA: float = 12.0
const SAMPLE_LOSS: float = -3.0
const SAMPLE_POPULATION: float = 328200000.0
const SAMPLE_SHARES: Array[float] = [0.0, 0.42, 1.0]
const SHARE_NAMES: Array[String] = ["zero", "partial", "full"]

## The values the "changing" bar walks through, and how long it waits between two.
const CYCLE_SHARES: Array[float] = [0.2, 0.55, 0.9, 0.35]
const CYCLE_SECONDS: float = 1.2

## §7.8's link states, side by side: a run shows one kind at a time and never a
## closed link at all, so this is the only place the four can be compared.
const LINK_CELL: Vector2 = Vector2(160.0, 56.0)
## §7.7's marker in its two states; the box is wide enough for the ring at its
## widest.
const MARKER_CELL: Vector2 = Vector2(56.0, 56.0)
const MARKER_DAYS_LEFT: int = 12

const STAT_BAR_SCENE: String = "res://ui/components/stat_bar.tscn"
## Where `F12` puts a picture of the gallery: locale and logical width.
const SHOT_PATH: String = "user://gallery_%s_%d.png"
## Wide enough for a bar to read, narrow enough that three fit on one row at
## 1920 and wrap at 400.
const BAR_WIDTH: float = 280.0

## §5.7's breakpoint. Below it the gallery lays out one logical pixel per window
## pixel, the way a phone does (§6.1) — a desktop window is otherwise scaled from
## the 1920 base, and a 400 px window would show the wide layout shrunk instead
## of the narrow one this screen exists to review.
const COMPACT_WIDTH: int = 1100

@onready var _ground: ColorRect = %Ground
@onready var _column: VBoxContainer = %Column

var _changing: StatBar = null
var _cycle_step: int = 0
var _slide: SlidePanel = null


func _ready() -> void:
	theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	_ground.color = UiTokens.BG_1
	get_window().size_changed.connect(_on_window_size_changed)
	_on_window_size_changed()
	_build_labels()
	_build_panels()
	_build_buttons()
	_build_icon_buttons()
	_build_chips()
	_build_value_labels()
	_build_stat_bars()
	_build_map_layers()
	_build_slide_panel()
	var cycle: Timer = Timer.new()
	cycle.wait_time = CYCLE_SECONDS
	cycle.timeout.connect(_cycle_changing)
	add_child(cycle)
	cycle.start()


## `F12` writes the view to `user://` under the locale and width it was taken at,
## so a review (G2) can compare the same four pictures on any machine without a
## screenshot tool. `L` is the locale key of `Game`, which works here too.
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F12:
		return
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = SHOT_PATH % [TranslationServer.get_locale(), int(size.x)]
	print("gallery shot: %s -> %s" % [ProjectSettings.globalize_path(path),
		error_string(image.save_png(path))])
	get_viewport().set_input_as_handled()


## A zero content scale means "use the project's base", so the wide window keeps
## the 1920 layout and the narrow one becomes the phone.
func _on_window_size_changed() -> void:
	var window: Window = get_window()
	window.content_scale_size = window.size if window.size.x < COMPACT_WIDTH else Vector2i.ZERO


## The "changing" bar steps through a fixed cycle, so that the tween of §4.4 and
## the flash it triggers are visible in the running gallery — and so that a
## screenshot is the same every time.
func _cycle_changing() -> void:
	if _changing == null:
		return
	_cycle_step = (_cycle_step + 1) % CYCLE_SHARES.size()
	_changing.set_value(CYCLE_SHARES[_cycle_step])


# ------------------------------------------------------------------- sections


func _build_labels() -> void:
	var row: HFlowContainer = _section("Type scale")
	for variation: String in ["LabelDisplay", "LabelHeading", "ValueLabelLarge", "LabelCaption"]:
		var label: Label = Label.new()
		label.theme_type_variation = StringName(variation)
		# A `Label` translates its own text and re-renders when the locale
		# changes, so the key itself is what it is given.
		label.text = KEY_PROFILE
		if variation == "ValueLabelLarge":
			label.text = Format.number(SAMPLE_COMPUTE, Format.Kind.COMPUTE)
		_state(row, variation, label)
	var caps: CapsLabel = CapsLabel.new()
	caps.label_key = KEY_PROFILE
	_state(row, "LabelCaps", caps)
	_state(row, "body", _body_label(false))


func _build_panels() -> void:
	var row: HFlowContainer = _section("ConsolePanel")
	_state(row, "default", _panel(false, false, ""))
	_state(row, "titled", _panel(false, false, KEY_PROFILE))
	_state(row, "raised", _panel(true, false, KEY_PROFILE))
	_state(row, "alert", _panel(false, true, KEY_PROFILE))


func _build_buttons() -> void:
	var row: HFlowContainer = _section("ConsoleButton")
	_state(row, "normal", _button(DOCK_KEYS[0], false, false, false))
	_state(row, "toggled", _button(DOCK_KEYS[1], false, true, false))
	_state(row, "disabled", _button(DOCK_KEYS[2], false, false, true))
	_state(row, "primary", _button(KEY_COLLECT, true, false, false))
	_state(row, "primary disabled", _button(KEY_COLLECT, true, false, true))
	var focused: ConsoleButton = _button(KEY_CLOSE, false, false, false)
	_state(row, "focus", focused)
	focused.grab_focus.call_deferred()


func _build_icon_buttons() -> void:
	var row: HFlowContainer = _section("IconButton")
	var names: Array = IconButton.Glyph.keys()
	var glyphs: Array = IconButton.Glyph.values()
	for i: int in names.size():
		var button: IconButton = IconButton.new()
		button.glyph = glyphs[i]
		button.tooltip_key = SPEED_KEYS[i] if i < SPEED_KEYS.size() else KEY_CLOSE
		_state(row, str(names[i]), button)
	var disabled: IconButton = IconButton.new()
	disabled.glyph = IconButton.Glyph.CLOSE
	disabled.tooltip_key = KEY_CLOSE
	disabled.disabled = true
	_state(row, "disabled", disabled)


func _build_chips() -> void:
	var row: HFlowContainer = _section("Chip")
	var kinds: Array[Chip.Kind] = [Chip.Kind.DEFAULT, Chip.Kind.ACCENT, Chip.Kind.ALERT]
	var names: Array[String] = ["default", "accent", "alert"]
	for i: int in kinds.size():
		var chip: Chip = Chip.new()
		chip.kind = kinds[i]
		chip.label_key = CHIP_KEYS[i]
		_state(row, names[i], chip)
	var long_chip: Chip = Chip.new()
	long_chip.kind = Chip.Kind.ALERT
	long_chip.label_key = KEY_DARK
	_state(row, "long text", long_chip)


func _build_value_labels() -> void:
	var row: HFlowContainer = _section("ValueLabel")
	_state(row, "neutral", _value(SAMPLE_COMPUTE, Format.Kind.COMPUTE, NAN, false))
	_state(row, "up", _value(SAMPLE_COMPUTE, Format.Kind.COMPUTE, SAMPLE_DELTA, false))
	_state(row, "down", _value(SAMPLE_COMPUTE, Format.Kind.COMPUTE, SAMPLE_LOSS, false))
	_state(row, "muted", _value(SAMPLE_COMPUTE, Format.Kind.COMPUTE, 0.0, false))
	_state(row, "large", _value(SAMPLE_COMPUTE, Format.Kind.COMPUTE, NAN, true))
	_state(row, "compact", _value(SAMPLE_POPULATION, Format.Kind.COMPACT, NAN, false))
	_state(row, "percent", _value(SAMPLE_SHARES[1], Format.Kind.PERCENT, NAN, false))


func _build_stat_bars() -> void:
	var row: HFlowContainer = _section("StatBar")
	for i: int in SAMPLE_SHARES.size():
		_state(row, SHARE_NAMES[i], _bar(STAT_VARIATIONS[i], STAT_KEYS[i], SAMPLE_SHARES[i],
			false))
	_changing = _bar(STAT_VARIATIONS[0], STAT_KEYS[0], SAMPLE_SHARES[1], false)
	_state(row, "changing", _changing)
	var compact: HFlowContainer = _section("StatBar — compact (§5.7)")
	for i: int in STAT_VARIATIONS.size():
		_state(compact, SHARE_NAMES[i], _bar(STAT_VARIATIONS[i], STAT_KEYS[i],
			SAMPLE_SHARES[i], true))


## The two things the map draws that are not components (§7.7, §7.8). They are
## in the gallery because a run shows them one at a time and, in the case of a
## closed link, never: nothing in M2 closes one.
func _build_map_layers() -> void:
	var links: HFlowContainer = _section("Link kinds (§7.8)")
	for kind: String in LinkDef.KINDS:
		_state(links, kind, _link_cell(kind, true, false))
	_state(links, "land flowing", _link_cell(LinkDef.KIND_LAND, true, true))
	_state(links, "sea flowing", _link_cell(LinkDef.KIND_SEA, true, true))
	_state(links, "closed", _link_cell(LinkDef.KIND_LAND, false, false))

	var markers: HFlowContainer = _section("Anomaly marker (§7.7)")
	_state(markers, "collectable", _marker_cell(MARKER_DAYS_LEFT))
	_state(markers, "last days", _marker_cell(AnomalyMarker.BLINK_DAYS))


## The slide panel lives over everything else, so it is a child of the root and
## a button in its section opens it.
func _build_slide_panel() -> void:
	_slide = SlidePanel.new()
	_slide.edge = SlidePanel.Edge.LEFT
	var panel: ConsolePanel = _panel(false, false, KEY_PROFILE)
	panel.custom_minimum_size = Vector2.ZERO
	_slide.add_child(panel)
	add_child(_slide)
	var close: IconButton = IconButton.new()
	close.glyph = IconButton.Glyph.CLOSE
	close.tooltip_key = KEY_CLOSE
	close.pressed.connect(_slide.close)
	panel.content.add_child(close)
	var row: HFlowContainer = _section("SlidePanel")
	var open: ConsoleButton = _button(DOCK_KEYS[0], true, false, false)
	open.pressed.connect(_slide.open)
	_state(row, "open / close", open)


# --------------------------------------------------------------- the pieces


## A titled section: a heading and the flow row its states go into. The row wraps,
## so the same gallery reads at 1920 and at 400.
func _section(title: String) -> HFlowContainer:
	var heading: Label = Label.new()
	heading.theme_type_variation = &"LabelHeading"
	heading.text = title
	_column.add_child(heading)
	var row: HFlowContainer = HFlowContainer.new()
	row.theme_type_variation = &"Flow"
	_column.add_child(row)
	return row


## One state: the component with its name underneath.
func _state(row: HFlowContainer, name_text: String, node: Control) -> void:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.theme_type_variation = &"PanelContent"
	cell.add_child(node)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"LabelCaption"
	caption.text = name_text
	cell.add_child(caption)
	row.add_child(cell)


func _panel(raised: bool, alert: bool, title_key: String) -> ConsolePanel:
	var panel: ConsolePanel = ConsolePanel.new()
	panel.raised = raised
	panel.alert = alert
	panel.title_key = title_key
	panel.custom_minimum_size = Vector2(BAR_WIDTH, 0.0)
	panel.add_child(_body_label(true))
	return panel


## A line of body text, given the key so that the engine translates it. It wraps
## inside a panel, which has a width; on its own it must not, or a flow row
## squeezes it to one letter per line.
func _body_label(wrapping: bool) -> Label:
	var label: Label = Label.new()
	label.text = KEY_TICKER_IDLE
	if wrapping:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(key: String, primary: bool, toggled: bool, disabled: bool) -> ConsoleButton:
	var button: ConsoleButton = ConsoleButton.new()
	button.label_key = key
	button.primary = primary
	button.disabled = disabled
	if toggled:
		button.toggle_mode = true
		button.button_pressed = true
	if disabled:
		button.tooltip_key = KEY_NOT_YET
	return button


## `NAN` as the delta means the label has none.
func _value(value: float, kind: Format.Kind, delta: float, large: bool) -> ValueLabel:
	var label: ValueLabel = ValueLabel.new()
	label.large = large
	label.set_number(value, kind)
	if not is_nan(delta):
		label.set_delta(delta, Format.Kind.COMPUTE)
	return label


## A link drawn across a box of its own. The map's layers are `Node2D`s, so the
## sample sits inside a `Control` that gives the flow row something to lay out.
func _link_cell(kind: String, is_open: bool, flowing: bool) -> Control:
	var cell: Control = Control.new()
	cell.custom_minimum_size = LINK_CELL
	var line: LinkLine = LinkLine.new()
	cell.add_child(line)
	line.setup(Vector2(0.0, LINK_CELL.y * 0.5), Vector2(LINK_CELL.x, LINK_CELL.y * 0.5),
		kind)
	line.set_open(is_open)
	line.set_flowing(flowing, true)
	return cell


func _marker_cell(days_left: int) -> Control:
	var cell: Control = Control.new()
	cell.custom_minimum_size = MARKER_CELL
	var marker: AnomalyMarker = AnomalyMarker.new()
	marker.position = MARKER_CELL * 0.5
	cell.add_child(marker)
	marker.days_left = days_left
	return cell


func _bar(variation: String, key: String, share: float, compact: bool) -> StatBar:
	var scene: PackedScene = load(STAT_BAR_SCENE) as PackedScene
	var bar: StatBar = scene.instantiate() as StatBar
	bar.theme_type_variation = StringName(variation)
	bar.label_key = key
	bar.compact = compact
	bar.custom_minimum_size.x = BAR_WIDTH
	bar.ready.connect(bar.set_value.bind(share))
	return bar
