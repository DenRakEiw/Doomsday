extends GutTest
## S2.6 — what an anomaly marker looks like (spec ui-foundation.md §7.7).
##
## The pulse, the countdown and the hit area are pure functions of a phase, a
## number of days and a zoom, so all three are checked as values. Whether the
## ring is actually painted is the running game's business (and G2's).

func test_the_ring_grows_out_of_the_disc_and_fades_as_it_goes() -> void:
	var start: Array = AnomalyMarker.ring_for(0.0)
	var end: Array = AnomalyMarker.ring_for(1.0)
	assert_almost_eq(float(start[0]), AnomalyMarker.RING_RADIUS_MIN, 0.001)
	assert_almost_eq(float(start[1]), AnomalyMarker.RING_ALPHA_MAX, 0.001)
	assert_almost_eq(float(end[0]), AnomalyMarker.RING_RADIUS_MAX, 0.001)
	assert_almost_eq(float(end[1]), 0.0, 0.001)


func test_the_ring_never_leaves_its_range() -> void:
	for phase: float in [-1.0, 0.5, 2.0]:
		var ring: Array = AnomalyMarker.ring_for(phase)
		assert_between(float(ring[0]), AnomalyMarker.RING_RADIUS_MIN,
			AnomalyMarker.RING_RADIUS_MAX, "radius at %f" % phase)
		assert_between(float(ring[1]), 0.0, AnomalyMarker.RING_ALPHA_MAX,
			"alpha at %f" % phase)


## S3.P, from G3: the last days used to blink the disc red, which read as
## "danger, do not touch" rather than "hurry". Time is shown as time instead.
func test_the_countdown_ring_empties_with_the_days_left() -> void:
	const LIFETIME: int = 50
	assert_almost_eq(AnomalyMarker.countdown_for(LIFETIME, LIFETIME), 1.0, 0.001,
		"a whole ring on the day it spawned")
	assert_almost_eq(AnomalyMarker.countdown_for(LIFETIME / 2, LIFETIME), 0.5, 0.001,
		"half way through, half a ring")
	assert_eq(AnomalyMarker.countdown_for(0, LIFETIME), 0.0,
		"and nothing on the day it fades")


func test_the_countdown_ring_never_leaves_its_range() -> void:
	assert_eq(AnomalyMarker.countdown_for(-3, 50), 0.0, "a marker past its day")
	assert_eq(AnomalyMarker.countdown_for(80, 50), 1.0, "one that outlived its lifetime")
	assert_eq(AnomalyMarker.countdown_for(5, 0), 0.0, "and one without a lifetime at all")


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
