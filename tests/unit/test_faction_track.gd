extends GutTest
## S3.3, S4.4 — the containment track (spec m3-screens.md §4.2, opposition.md
## §9.2).
##
## The bands are read from `balance.containment.thresholds`, so the test uses the
## fixture's thresholds rather than the numbers the spec happens to name.

const FACTION_TRACK: PackedScene = preload("res://ui/components/faction_track.tscn")
const KEY_NAME: String = "FACTION_GOVERNMENTS"

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
	track.bind(KEY_NAME, 0.3, 0.001, _thresholds)
	var bar: StatBar = track.get_node("%TrackBar") as StatBar
	var expected: Array[float] = _thresholds.duplicate()
	expected.append(1.0)
	assert_eq(bar.ticks, expected)
	assert_eq(String(bar.theme_type_variation), "StatBarContainment")


func test_a_rollback_slides_the_bar_back() -> void:
	var track: FactionTrack = _track()
	track.bind(KEY_NAME, 0.8, 0.001, _thresholds)
	# Reduced motion is on in the suite, so the slide finishes at once.
	track.flash_rollback(0.8, 0.6)
	var bar: StatBar = track.get_node("%TrackBar") as StatBar
	assert_almost_eq(bar.value(), 0.6, 1e-6)


func _breakdown(contributions: Array[float], brakes: float) -> Dictionary:
	var terms: Array[Dictionary] = []
	var sources: Array[String] = ["footprint", "share", "owned_nodes"]
	for i: int in contributions.size():
		terms.append({
			ContainmentSystem.TERM_SOURCE: sources[i],
			ContainmentSystem.TERM_TREE: "capabilities",
			ContainmentSystem.TERM_KIND: "",
			ContainmentSystem.TERM_WEIGHT: 1.0,
			ContainmentSystem.TERM_VALUE: contributions[i],
			ContainmentSystem.TERM_CONTRIBUTION: contributions[i],
		})
	return {
		ContainmentSystem.TERMS: terms,
		ContainmentSystem.PRESSURE: 2.0,
		ContainmentSystem.CAPACITY: 0.8,
		ContainmentSystem.BRAKES: brakes,
		ContainmentSystem.GAIN: 0.002,
	}


func test_the_detail_lists_the_two_largest_terms_largest_first() -> void:
	var track: FactionTrack = _track()
	track.bind(KEY_NAME, 0.3, 0.001, _thresholds)
	track.bind_detail(_breakdown([0.2, 0.1, 0.5], 1.0), {}, -1, false)
	var first: Label = track.get_node("%TermA") as Label
	var second: Label = track.get_node("%TermB") as Label
	assert_true(first.visible and second.visible)
	assert_string_contains(first.text, Format.addend(0.5), "the owned-nodes term leads")
	assert_string_contains(second.text, Format.addend(0.2), "then the footprint; the share is third")


func test_a_term_at_zero_is_not_shown() -> void:
	var track: FactionTrack = _track()
	track.bind_detail(_breakdown([0.3, 0.0, 0.0], 1.0), {}, -1, false)
	assert_true((track.get_node("%TermA") as Label).visible)
	assert_false((track.get_node("%TermB") as Label).visible, "the row shrinks")


func test_a_brake_below_one_reads_in_the_accent() -> void:
	var track: FactionTrack = _track()
	track.bind_detail(_breakdown([0.3], 0.6), {}, -1, false)
	var brakes: Label = track.get_node("%Brakes") as Label
	assert_eq(String(brakes.theme_type_variation), "LabelCaptionAccent")
	track.bind_detail(_breakdown([0.3], 1.0), {}, -1, false)
	assert_eq(String(brakes.theme_type_variation), "LabelCaption")


func test_the_leader_carries_the_leading_chip() -> void:
	var track: FactionTrack = _track()
	track.bind_detail(_breakdown([0.3], 1.0), {}, -1, true)
	assert_true((track.get_node("%Leading") as Control).visible)
	track.bind_detail(_breakdown([0.3], 1.0), {}, -1, false)
	assert_false((track.get_node("%Leading") as Control).visible)


func test_an_empty_breakdown_hides_the_detail() -> void:
	var track: FactionTrack = _track()
	track.bind_detail({}, {}, -1, false)
	assert_false((track.get_node("%Detail") as Control).visible)
	assert_false((track.get_node("%Terms") as Control).visible)
	assert_false((track.get_node("%Next") as Control).visible, "no move before S4.5")


func test_the_glyph_names_the_faction() -> void:
	var track: FactionTrack = _track()
	track.set_faction("public_sentiment")
	var glyph: GlyphIcon = track.get_node("%TrackGlyph") as GlyphIcon
	assert_true(glyph.visible)
	assert_eq(glyph.glyph, Glyphs.Glyph.FACTION_PUBLIC)
	assert_eq(glyph.color_token, &"FACTION_PUBLIC")
