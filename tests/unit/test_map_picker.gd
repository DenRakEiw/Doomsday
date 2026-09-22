extends GutTest
## S2.3 — screen point → region index (spec ui-foundation.md §7.4).
##
## The real ID map and the real region anchors, because that is what a mis-click
## would be about. The camera is present only as its transform, which is what
## makes the whole of picking checkable without a viewport.

const ID_MAP: Texture2D = preload("res://assets/map/id_map.png")
const CONTENT_ROOT: String = "res://data"
## §7.4 names these three.
const ANCHOR_REGIONS: Array[String] = ["usa", "germany", "japan"]
## The middle of the South Atlantic: no land for hundreds of map pixels.
const OCEAN_PIXEL: Vector2 = Vector2(2100.0, 1450.0)
const VIEWPORT: Vector2 = Vector2(1920.0, 1080.0)

static var _image: Image = null
static var _db: ContentDB = null


func before_all() -> void:
	if _image == null:
		_image = ID_MAP.get_image()
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(CONTENT_ROOT)
		assert_true(result.ok(), "the shipped content must load")
		_db = result.db


## The centre of a map pixel, on screen, for a camera looking at `center`.
func _screen_of(pixel: Vector2, center: Vector2, zoom: float) -> Vector2:
	return MapCamera.transform_for(center, zoom, VIEWPORT) * (pixel + Vector2(0.5, 0.5))


func _pick(pixel: Vector2, center: Vector2, zoom: float) -> int:
	return MapPicker.region_at_transform(
		_screen_of(pixel, center, zoom), MapCamera.transform_for(center, zoom, VIEWPORT),
		_image)


func test_the_id_map_is_the_size_the_spec_states() -> void:
	assert_eq(_image.get_width(), 4096)
	assert_eq(_image.get_height(), 2048)


func test_each_anchor_picks_its_own_region_at_the_start_zoom() -> void:
	var zoom: float = MapCamera.zoom_min_for(VIEWPORT)
	for id: String in ANCHOR_REGIONS:
		var region: RegionDef = _db.region_by_id(id)
		assert_not_null(region, id)
		assert_eq(_pick(Vector2(region.anchor), MapCamera.START_CENTER, zoom),
			region.index, id)


func test_each_anchor_picks_its_own_region_zoomed_in_and_panned() -> void:
	for id: String in ANCHOR_REGIONS:
		var region: RegionDef = _db.region_by_id(id)
		# The camera is put somewhere else than on the anchor on purpose: a
		# picker that ignored the pan would still pass a centred test.
		var center: Vector2 = Vector2(region.anchor) + Vector2(-180.0, 90.0)
		assert_eq(_pick(Vector2(region.anchor), center, 3.0), region.index, id)


func test_open_water_is_no_region() -> void:
	var zoom: float = MapCamera.zoom_min_for(VIEWPORT)
	assert_eq(_pick(OCEAN_PIXEL, MapCamera.START_CENTER, zoom), MapPicker.NO_REGION)


func test_a_point_off_the_map_is_no_region() -> void:
	for pixel: Vector2 in [Vector2(-1.0, 10.0), Vector2(10.0, -1.0),
			Vector2(4096.0, 10.0), Vector2(10.0, 2048.0)]:
		assert_eq(MapPicker.index_at(pixel, _image), MapPicker.NO_REGION, str(pixel))


func test_a_pixel_covers_its_own_square_and_not_the_next_one() -> void:
	var region: RegionDef = _db.region_by_id("usa")
	var pixel: Vector2 = Vector2(region.anchor)
	assert_eq(MapPicker.index_at(pixel + Vector2(0.999, 0.999), _image), region.index,
		"the far corner still belongs to the pixel")


func test_without_an_image_nothing_is_picked() -> void:
	assert_eq(MapPicker.index_at(Vector2.ZERO, null), MapPicker.NO_REGION)


func test_the_screen_point_a_map_pixel_sits_at_comes_back_as_that_pixel() -> void:
	var canvas: Transform2D = MapCamera.transform_for(Vector2(1000.0, 600.0), 2.5, VIEWPORT)
	var pixel: Vector2 = MapPicker.map_pixel(canvas * Vector2(1234.0, 567.0), canvas)
	assert_almost_eq(pixel.x, 1234.0, 0.001)
	assert_almost_eq(pixel.y, 567.0, 0.001)
