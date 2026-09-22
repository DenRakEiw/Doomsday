extends GutTest
## S3.3 — the containment track (spec m3-screens.md §4.2).
##
## The bands are read from `balance.containment.thresholds`, so the test uses the
## fixture's thresholds rather than the numbers the spec happens to name.

const FACTION_TRACK: PackedScene = preload("res://ui/components/faction_track.tscn")
const KEY_UNIFIED: String = "FACTION_UNIFIED"

var _root: Control = null
var _thresholds: Array[float] = []
var _reduced_motion: bool = false


func before_each() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.set_reduced_motion(true)
	_thresholds = Fixtures.db().balance.containment_thresholds
	_root = Control.new()
	_root.theme = ThemeBuilder.build(ThemeBuilder.VARIANT_COLD)
	add_child_autofree(_root)


func after_each() -> void:
	Settings.set_reduced_motion(_reduced_motion)


func _track() -> FactionTrack:
	var track: FactionTrack = FACTION_TRACK.instantiate()
	_root.add_child(track)
	return track


func test_band_from_thresholds() -> void:
	assert_eq(FactionTrack.band_of(0.0, _thresholds), FactionTrack.Band.QUIET)
	assert_eq(FactionTrack.band_of(_thresholds[0] - 0.01, _thresholds), FactionTrack.Band.QUIET)
	assert_eq(FactionTrack.band_of(_thresholds[0], _thresholds), FactionTrack.Band.ALERT)
	assert_eq(FactionTrack.band_of(_thresholds[1], _thresholds), FactionTrack.Band.MOBILISED)
	assert_eq(FactionTrack.band_of(_thresholds[2], _thresholds), FactionTrack.Band.CLOSING)
	assert_eq(FactionTrack.band_of(1.0, _thresholds), FactionTrack.Band.CLOSING)


func test_the_band_chip_follows_the_band() -> void:
	assert_eq(FactionTrack.band_kind(0.0, _thresholds), Chip.Kind.DEFAULT)
	assert_eq(FactionTrack.band_kind(_thresholds[0], _thresholds), Chip.Kind.ACCENT)
	assert_eq(FactionTrack.band_kind(_thresholds[2], _thresholds), Chip.Kind.ALERT)


## The marks on the bar are the thresholds plus the end of the run (§4.2).
func test_the_bar_is_marked_at_every_threshold_and_at_one() -> void:
	var track: FactionTrack = _track()
	track.bind(KEY_UNIFIED, 0.3, 0.001, _thresholds)
	var bar: StatBar = track.get_node("%TrackBar") as StatBar
	var expected: Array[float] = _thresholds.duplicate()
	expected.append(1.0)
	assert_eq(bar.ticks, expected)
	assert_eq(String(bar.theme_type_variation), "StatBarContainment")


func test_a_rollback_slides_the_bar_back() -> void:
	var track: FactionTrack = _track()
	track.bind(KEY_UNIFIED, 0.8, 0.001, _thresholds)
	# Reduced motion is on in the suite, so the slide finishes at once.
	track.flash_rollback(0.8, 0.6)
	var bar: StatBar = track.get_node("%TrackBar") as StatBar
	assert_almost_eq(bar.value(), 0.6, 1e-6)
