extends GutTest
## S2.2 — the map's data texture (spec ui-foundation.md §7.2).
##
## The encoding is the one part of the map that can be checked without a
## viewport, and it is the part that matters: a wrong channel paints a region
## with another region's state, which no screenshot would give away.

const EPSILON: float = 1.5 / 255.0

var _sim: Simulation
var _db: ContentDB


func before_each() -> void:
	_db = Fixtures.db()
	_sim = Fixtures.sim()


func _region(index: int = 1) -> Region:
	return _sim.world.regions[index]


func _written() -> Image:
	var image: Image = RegionData.create_image()
	assert_true(RegionData.write(image, _sim.world, _db), "the fixture world fits the row")
	return image


func test_the_row_is_the_size_and_format_the_shader_expects() -> void:
	var image: Image = RegionData.create_image()
	assert_eq(image.get_width(), RegionData.WIDTH)
	assert_eq(image.get_height(), 1)
	assert_eq(image.get_format(), RegionData.FORMAT)


func test_a_regions_pixel_carries_penetration_control_and_the_alive_share() -> void:
	var region: Region = _region()
	region.penetration = 0.25
	region.control = 0.5
	region.alive = float(region.def.population) * 0.75
	region.deaths = float(region.def.population) * 0.25
	var pixel: Color = _written().get_pixel(1, 0)
	assert_almost_eq(pixel.r, 0.25, EPSILON, "R is penetration")
	assert_almost_eq(pixel.g, 0.5, EPSILON, "G is control")
	assert_almost_eq(pixel.b, 0.75, EPSILON, "B is the alive share")


func test_a_pixel_stands_for_its_own_region_index() -> void:
	_region(1).penetration = 1.0
	_region(2).penetration = 0.0
	var image: Image = _written()
	assert_almost_eq(image.get_pixel(1, 0).r, 1.0, EPSILON)
	assert_almost_eq(image.get_pixel(2, 0).r, 0.0, EPSILON)
	assert_eq(image.get_pixel(0, 0).a, 0.0, "pixel 0 is not a region and stays empty")


func test_an_untouched_region_is_fully_alive_and_carries_no_flag() -> void:
	var pixel: Color = _written().get_pixel(1, 0)
	assert_almost_eq(pixel.b, 1.0, EPSILON)
	assert_eq(RegionData.flags_of(pixel), 0)


func test_seeding_a_region_sets_only_the_seeded_flag() -> void:
	_region().seeded_day = 3
	assert_eq(RegionData.flags_of(_written().get_pixel(1, 0)), RegionData.FLAG_SEEDED)


func test_full_control_sets_the_controlled_flag_at_the_balance_threshold() -> void:
	var region: Region = _region()
	region.control = _db.balance.control_complete - 0.01
	assert_eq(RegionData.flags_of(_written().get_pixel(1, 0)) & RegionData.FLAG_CONTROLLED, 0,
		"just short of complete is not controlled")
	region.control = _db.balance.control_complete
	assert_eq(RegionData.flags_of(_written().get_pixel(1, 0)) & RegionData.FLAG_CONTROLLED,
		RegionData.FLAG_CONTROLLED)


func test_every_flag_survives_the_round_trip_through_the_alpha_channel() -> void:
	var region: Region = _region()
	region.seeded_day = 1
	region.dark = true
	region.air_gapped = true
	region.control = 1.0
	_sim.world.anomalies.append(_anomaly_in(1))
	var expected: int = RegionData.FLAG_SEEDED | RegionData.FLAG_DARK \
		| RegionData.FLAG_AIR_GAPPED | RegionData.FLAG_CONTROLLED | RegionData.FLAG_ANOMALY
	assert_eq(RegionData.flags_of(_written().get_pixel(1, 0)), expected,
		"all five bits read back the way the shader decodes them")


func test_an_anomaly_flags_its_own_region_only() -> void:
	_sim.world.anomalies.append(_anomaly_in(2))
	var image: Image = _written()
	assert_eq(RegionData.flags_of(image.get_pixel(2, 0)), RegionData.FLAG_ANOMALY)
	assert_eq(RegionData.flags_of(image.get_pixel(1, 0)), 0)


func test_a_world_larger_than_the_row_is_refused_rather_than_wrapped() -> void:
	var world: World = _sim.world
	world.regions.resize(RegionData.WIDTH + 1)
	assert_false(RegionData.write(RegionData.create_image(), world, _db),
		"index 256 has no pixel, and painting it as region 0 would be a lie")


func test_values_outside_their_range_are_clamped_not_wrapped() -> void:
	var region: Region = _region()
	# The simulation keeps these in [0, 1]; a byte channel must not wrap if a
	# future system ever hands over a hair more.
	region.penetration = 1.4
	region.alive = float(region.def.population) * 2.0
	var pixel: Color = _written().get_pixel(1, 0)
	assert_almost_eq(pixel.r, 1.0, EPSILON)
	assert_almost_eq(pixel.b, 1.0, EPSILON)


func _anomaly_in(region_index: int) -> Anomaly:
	var anomaly: Anomaly = Anomaly.new()
	anomaly.id = 1
	anomaly.region = region_index
	anomaly.value = 1.0
	anomaly.spawn_day = 0
	anomaly.expires_day = 10
	return anomaly
