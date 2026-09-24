extends GutTest
## S5.7 — the title's globe (spec screens-full.md §3.1): the data texture a
## history entry makes, where the globe rests, and the spin reduced motion stops.


func _db() -> ContentDB:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	return result.db


func test_the_data_texture_lights_reached_and_controlled_regions() -> void:
	var image: Image = Globe.data_image({"regions": [3, 7, 12], "controlled": [7]})
	assert_eq(image.get_width(), RegionData.WIDTH)
	assert_eq(image.get_height(), 1)
	assert_eq(image.get_pixel(3, 0).r, 1.0, "reached")
	assert_eq(image.get_pixel(3, 0).g, 0.0, "reached, not controlled")
	assert_eq(image.get_pixel(7, 0).r, 1.0, "controlled is reached as well")
	assert_eq(image.get_pixel(7, 0).g, 1.0)
	assert_eq(image.get_pixel(4, 0).r, 0.0, "a region the run never reached stays plain")
	assert_eq(image.get_pixel(0, 0).r, 0.0, "index 0 is no region")


func test_no_history_is_plain_land() -> void:
	var image: Image = Globe.data_image({})
	for i: int in RegionData.WIDTH:
		assert_eq(image.get_pixel(i, 0).r + image.get_pixel(i, 0).g, 0.0)


func test_indices_outside_the_texture_are_ignored() -> void:
	var image: Image = Globe.data_image({"regions": [-1, 0, 999]})
	assert_eq(image.get_pixel(0, 0).r, 0.0)


func test_the_globe_rests_on_the_last_origin() -> void:
	var db: ContentDB = _db()
	# The authored anchors (tools/map/region_attributes.csv) run through the
	# Equal Earth inverse; a degree either way is invisible on a globe.
	assert_almost_eq(Globe.rest_longitude({"origin": "usa"}, db), -95.0, 1.0)
	assert_almost_eq(Globe.rest_longitude({"origin": "canada"}, db), -102.0, 1.0)


func test_the_east_of_the_map_edge_reads_right() -> void:
	var db: ContentDB = _db()
	assert_almost_eq(Globe.rest_longitude({"origin": "japan"}, db), 138.5, 1.0)
	assert_almost_eq(Globe.rest_longitude({"origin": "new_zealand"}, db), 175.6, 1.0)


func test_without_a_run_the_globe_rests_at_ten_east() -> void:
	assert_eq(Globe.rest_longitude({}, _db()), Globe.REST_LONGITUDE)
	assert_eq(Globe.rest_longitude({"origin": "atlantis"}, _db()), Globe.REST_LONGITUDE,
		"a region the content lost is no origin")
	assert_eq(Globe.REST_LONGITUDE, 10.0)


func test_reduced_motion_stops_the_spin() -> void:
	assert_eq(Globe.spin_rate(true), 0.0)
	assert_almost_eq(Globe.spin_rate(false) * Globe.TURN_SECONDS, TAU, 0.0001,
		"a full turn in 90 s")
