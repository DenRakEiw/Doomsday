extends GutTest
## S2.6 — what an anomaly marker looks like (spec ui-foundation.md §7.7).
##
## The pulse, the blink and the hit area are pure functions of a phase, a number
## of days and a zoom, so all three are checked as values. Whether the ring is
## actually painted is the running game's business (and G2's).

func test_the_ring_grows_out_of_the_disc_and_fades_as_it_goes() -> void:
	var start: Array = AnomalyMarker.ring_for(0.0, false)
	var end: Array = AnomalyMarker.ring_for(1.0, false)
	assert_almost_eq(float(start[0]), AnomalyMarker.RING_RADIUS_MIN, 0.001)
	assert_almost_eq(float(start[1]), AnomalyMarker.RING_ALPHA_MAX, 0.001)
	assert_almost_eq(float(end[0]), AnomalyMarker.RING_RADIUS_MAX, 0.001)
	assert_almost_eq(float(end[1]), 0.0, 0.001)


func test_the_ring_never_leaves_its_range() -> void:
	for phase: float in [-1.0, 0.5, 2.0]:
		var ring: Array = AnomalyMarker.ring_for(phase, false)
		assert_between(float(ring[0]), AnomalyMarker.RING_RADIUS_MIN,
			AnomalyMarker.RING_RADIUS_MAX, "radius at %f" % phase)
		assert_between(float(ring[1]), 0.0, AnomalyMarker.RING_ALPHA_MAX,
			"alpha at %f" % phase)


func test_with_motion_off_the_ring_stands_still() -> void:
	for phase: float in [0.0, 0.3, 0.9]:
		var ring: Array = AnomalyMarker.ring_for(phase, true)
		assert_eq(float(ring[0]), AnomalyMarker.RING_STATIC_RADIUS, "radius")
		assert_eq(float(ring[1]), AnomalyMarker.RING_STATIC_ALPHA, "alpha")


func test_an_anomaly_with_time_left_is_the_accent() -> void:
	for elapsed: float in [0.0, 0.3, 1.7]:
		assert_eq(AnomalyMarker.disc_color(AnomalyMarker.BLINK_DAYS + 1, elapsed, false),
			UiTokens.ACCENT, "at %f" % elapsed)


func test_the_last_days_blink_between_the_accent_and_the_alert() -> void:
	var half: float = 0.5 / AnomalyMarker.BLINK_HZ
	assert_eq(AnomalyMarker.disc_color(AnomalyMarker.BLINK_DAYS, 0.0, false),
		UiTokens.ACCENT, "the first half of a period")
	assert_eq(AnomalyMarker.disc_color(AnomalyMarker.BLINK_DAYS, half + 0.01, false),
		UiTokens.ALERT, "the second")
	assert_eq(AnomalyMarker.disc_color(1, half * 2.0 + 0.01, false),
		UiTokens.ACCENT, "and round again")


func test_with_motion_off_the_last_days_are_simply_the_alert() -> void:
	for elapsed: float in [0.0, 0.4]:
		assert_eq(AnomalyMarker.disc_color(1, elapsed, true), UiTokens.ALERT,
			"'now' still has to be visible at %f" % elapsed)


func test_the_target_is_the_same_size_on_screen_at_every_zoom() -> void:
	var at: Vector2 = Vector2(1000.0, 500.0)
	for zoom: float in [0.5, 1.0, 4.0]:
		var reach: float = AnomalyMarker.HIT_RADIUS_PX / zoom
		assert_true(AnomalyMarker.hits(at, at + Vector2(reach * 0.9, 0.0), zoom),
			"inside at zoom %f" % zoom)
		assert_false(AnomalyMarker.hits(at, at + Vector2(reach * 1.1, 0.0), zoom),
			"outside at zoom %f" % zoom)


func test_the_target_is_the_minimum_tap_size_of_the_tokens() -> void:
	assert_eq(AnomalyMarker.HIT_RADIUS_PX * 2.0, float(UiTokens.HIT_MIN),
		"48 dp across, on every platform")


func test_without_a_zoom_nothing_is_hit() -> void:
	assert_false(AnomalyMarker.hits(Vector2.ZERO, Vector2.ZERO, 0.0))
