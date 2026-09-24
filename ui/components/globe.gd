class_name Globe
extends ColorRect
## The title's globe (spec `screens-full.md` §3.1): a `ColorRect` and a shader
## that draws a turning sphere from an equirectangular region-ID texture, and
## lights the regions the last run reached.
##
## No 3D node, ever, unless G5 decides so (VISUALS question 2). Not interactive
## in M5.

const SHADER_PATH: String = "res://ui/components/globe.gdshader"
const IDS_PATH: String = "res://assets/map/globe_ids.png"

## A full turn in 90 s; the axis tilted 18° towards the viewer; the terminator
## 70° from the view axis, the dark side at 40 %.
const TURN_SECONDS: float = 90.0
const TILT_DEGREES: float = -18.0
const TERMINATOR_DEGREES: float = 70.0
const NIGHT: float = 0.4
## How much of `STAT_PENETRATION` reached and controlled land take.
const REACHED_MIX: float = 0.35
const CONTROLLED_MIX: float = 0.7
## Where the globe rests without a run to show (§3.1: 10° E).
const REST_LONGITUDE: float = 10.0

## The history entry's keys (`ProfileManager._history_entry`).
const ENTRY_REGIONS: String = "regions"
const ENTRY_CONTROLLED: String = "controlled"
const ENTRY_ORIGIN: String = "origin"

## The data texture: 256 × 1, R = reached, G = controlled (`RegionData`'s
## width and its convention).
const DATA_WIDTH: int = RegionData.WIDTH
const DATA_HEIGHT: int = 1

## The map's frame (tools/map/build_map.py): Equal Earth, central meridian 11° E,
## half the projected width in metres, 4096 × 2048 pixels. An anchor is a map
## pixel; the globe needs its longitude.
const MAP_CENTRAL_MERIDIAN: float = 11.0
const MAP_HALF_WIDTH_M: float = 17243959.06
const MAP_WIDTH_PX: float = 4096.0
const MAP_HEIGHT_PX: float = 2048.0
## Equal Earth's polynomial (Šavrič, Patterson, Jenny 2018).
const EE_A1: float = 1.340264
const EE_A2: float = -0.081106
const EE_A3: float = 0.000893
const EE_A4: float = 0.003796
const EE_NEWTON_STEPS: int = 12

var _material: ShaderMaterial = null
var _data: ImageTexture = null
## The longitude at the centre of the view, in degrees, and how far the globe
## has turned since (radians).
var _centre: float = REST_LONGITUDE
var _turn: float = 0.0


func _ready() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.0, 0.0, 0.0, 0.0)
	var shader: Shader = load(SHADER_PATH) as Shader
	var ids: Texture2D = load(IDS_PATH) as Texture2D
	if shader == null or ids == null:
		# §3.1's fallback: the title shows the backdrop alone, and says so once.
		push_warning("globe: the shader or its texture is missing; showing no globe")
		visible = false
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter(&"globe_ids", ids)
	_data = ImageTexture.create_from_image(data_image({}))
	_material.set_shader_parameter(&"region_data", _data)
	material = _material
	_apply_constants()
	resized.connect(_on_resized)
	EventBus.reduced_motion_changed.connect(_on_reduced_motion_changed)
	EventBus.theme_variant_changed.connect(_on_theme_variant_changed)
	_on_resized()


## Lights the run a history entry describes and turns the globe to its origin.
## An empty entry is plain land at rest on 10° E.
func show_run(entry: Dictionary, db: ContentDB) -> void:
	_centre = rest_longitude(entry, db)
	_turn = 0.0
	if _material == null:
		return
	_data.update(data_image(entry))
	_apply_motion()


## The data texture of an entry: region index → R reached, G controlled.
## Indices outside the texture are ignored.
static func data_image(entry: Dictionary) -> Image:
	var image: Image = Image.create(DATA_WIDTH, DATA_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var reached: Array = entry.get(ENTRY_REGIONS, [])
	var controlled: Array = entry.get(ENTRY_CONTROLLED, [])
	for value: Variant in reached:
		_mark(image, int(value), true, false)
	for value: Variant in controlled:
		_mark(image, int(value), true, true)
	return image


## The longitude the globe rests at (§3.1): the last run's origin, or 10° E.
static func rest_longitude(entry: Dictionary, db: ContentDB) -> float:
	var origin: String = str(entry.get(ENTRY_ORIGIN, ""))
	if origin.is_empty() or db == null or db.region_by_id(origin) == null:
		return REST_LONGITUDE
	return anchor_longitude(db.region_by_id(origin).anchor)


## A map pixel's longitude in degrees, −180…180: the Equal Earth inverse
## (latitude by Newton's method, then longitude).
static func anchor_longitude(anchor: Vector2i) -> float:
	var scale: float = 2.0 * MAP_HALF_WIDTH_M / MAP_WIDTH_PX
	var x: float = float(anchor.x) * scale - MAP_HALF_WIDTH_M
	var y: float = (MAP_HEIGHT_PX / 2.0 - float(anchor.y)) * scale
	# The authalic radius the map was projected with, recovered from its frame:
	# at the equator, 180° of longitude is the half width.
	var radius: float = MAP_HALF_WIDTH_M * EE_A1 * 3.0 / (2.0 * sqrt(3.0) * PI)
	var target: float = y / radius
	var theta: float = target
	for i: int in EE_NEWTON_STEPS:
		var f: float = theta * _ee_height(theta) - target
		theta -= f / _ee_slope(theta)
	var lam: float = x / radius * 3.0 * _ee_slope(theta) / (2.0 * sqrt(3.0) * cos(theta))
	return wrapf(rad_to_deg(lam) + MAP_CENTRAL_MERIDIAN, -180.0, 180.0)


## Equal Earth's y / θ, and dy/dθ — which is also the denominator of x.
static func _ee_height(theta: float) -> float:
	var t2: float = theta * theta
	return EE_A1 + EE_A2 * t2 + t2 * t2 * t2 * (EE_A3 + EE_A4 * t2)


static func _ee_slope(theta: float) -> float:
	var t2: float = theta * theta
	return EE_A1 + 3.0 * EE_A2 * t2 + t2 * t2 * t2 * (7.0 * EE_A3 + 9.0 * EE_A4 * t2)


## The spin in radians per second: none under reduced motion (§3.1).
static func spin_rate(reduced: bool) -> float:
	return 0.0 if reduced else TAU / TURN_SECONDS


static func _mark(image: Image, index: int, reached: bool, controlled: bool) -> void:
	if index <= 0 or index >= DATA_WIDTH:
		return
	var old: Color = image.get_pixel(index, 0)
	image.set_pixel(index, 0, Color(1.0 if reached else old.r,
		1.0 if controlled else old.g, 0.0, 1.0))


func _apply_constants() -> void:
	_material.set_shader_parameter(&"tilt", deg_to_rad(TILT_DEGREES))
	_material.set_shader_parameter(&"terminator", deg_to_rad(TERMINATOR_DEGREES))
	_material.set_shader_parameter(&"night", NIGHT)
	_material.set_shader_parameter(&"reached_mix", REACHED_MIX)
	_material.set_shader_parameter(&"controlled_mix", CONTROLLED_MIX)
	_apply_colours()
	_apply_motion()


func _apply_colours() -> void:
	_material.set_shader_parameter(&"ink_color", UiTokens.color(&"INK"))
	_material.set_shader_parameter(&"land_color", UiTokens.color(&"MAP_LAND"))
	_material.set_shader_parameter(&"border_color", UiTokens.color(&"MAP_BORDER"))
	_material.set_shader_parameter(&"reached_color", UiTokens.color(&"STAT_PENETRATION"))
	_material.set_shader_parameter(&"rim_color", UiTokens.color(&"ACCENT_DIM"))


## The Earth turns east, so the longitude facing the viewer falls. The turn is
## kept here rather than on the shader's `TIME`, which starts with
## the engine and rolls over: the globe starts on the origin whenever it shows.
func _apply_motion() -> void:
	_material.set_shader_parameter(&"centre_lon", deg_to_rad(_centre) - _turn)
	set_process(spin_rate(UiTokens.reduced_motion()) > 0.0)


func _process(delta: float) -> void:
	_turn = wrapf(_turn + spin_rate(false) * delta, 0.0, TAU)
	_material.set_shader_parameter(&"centre_lon", deg_to_rad(_centre) - _turn)


func _on_resized() -> void:
	if _material != null and size.y > 0.0:
		_material.set_shader_parameter(&"aspect", size.x / size.y)


func _on_reduced_motion_changed(_enabled: bool) -> void:
	_apply_motion()


func _on_theme_variant_changed(_variant: StringName) -> void:
	_apply_colours()
