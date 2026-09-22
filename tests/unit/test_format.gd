extends GutTest
## `Format` in both locales (spec ui-foundation.md §8.5, §11).
##
## Every case here is a rule from the table in §8.5. The locale is set per test
## and restored afterwards, because `TranslationServer` is global.

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _english() -> void:
	TranslationServer.set_locale("en")


func _german() -> void:
	TranslationServer.set_locale("de")


func test_plain_groups_thousands_in_english() -> void:
	_english()
	assert_eq(Format.number(1284.5, Format.Kind.PLAIN), "1,284.5")


func test_plain_groups_thousands_in_german() -> void:
	_german()
	assert_eq(Format.number(1284.5, Format.Kind.PLAIN), "1.284,5")


func test_plain_drops_a_trailing_zero_decimal() -> void:
	_english()
	assert_eq(Format.number(12.0, Format.Kind.PLAIN), "12")


func test_plain_rounds_to_one_decimal() -> void:
	_english()
	assert_eq(Format.number(12.34, Format.Kind.PLAIN), "12.3")


func test_compute_reads_as_plain() -> void:
	_german()
	assert_eq(Format.number(12.34, Format.Kind.COMPUTE), "12,3")


func test_compact_below_a_million_is_a_grouped_integer() -> void:
	_english()
	assert_eq(Format.number(12147.0, Format.Kind.COMPACT), "12,147")


func test_compact_below_a_million_is_grouped_the_german_way() -> void:
	_german()
	assert_eq(Format.number(12147.0, Format.Kind.COMPACT), "12.147")


## The boundary §11 asks for: one below the million is still a plain number.
func test_compact_at_the_million_boundary() -> void:
	_english()
	assert_eq(Format.number(999999.0, Format.Kind.COMPACT), "999,999")
	assert_string_contains(Format.number(1000000.0, Format.Kind.COMPACT), "1")
	assert_false(Format.number(1000000.0, Format.Kind.COMPACT).contains(","),
		"a million is one decimal and a unit, never a grouped integer")


func test_compact_uses_the_million_unit() -> void:
	_english()
	assert_eq(Format.number(328200000.0, Format.Kind.COMPACT), "328.2 %s" % tr("UI_FMT_MILLION"))


func test_compact_uses_the_billion_unit() -> void:
	_english()
	assert_eq(Format.number(1400000000.0, Format.Kind.COMPACT), "1.4 %s" % tr("UI_FMT_BILLION"))


func test_percent_has_no_space_in_english() -> void:
	_english()
	assert_eq(Format.percent(0.423), "42%")


func test_percent_has_a_space_in_german() -> void:
	_german()
	assert_eq(Format.percent(0.423), "42 %")


func test_percent_at_the_ends() -> void:
	_english()
	assert_eq(Format.percent(0.0), "0%")
	assert_eq(Format.percent(1.0), "100%")


func test_days_are_not_grouped() -> void:
	_english()
	assert_eq(Format.number(1170.0, Format.Kind.DAYS), "1170")


func test_a_negative_number_uses_the_minus_sign() -> void:
	_english()
	assert_eq(Format.number(-3.0, Format.Kind.PLAIN), Format.MINUS + "3")
	assert_false(Format.number(-3.0, Format.Kind.PLAIN).contains("-"),
		"a hyphen is not a minus sign")


func test_a_negative_percent_keeps_its_sign() -> void:
	_german()
	assert_eq(Format.percent(-0.12), Format.MINUS + "12 %")


func test_caps_spells_the_capital_of_the_sharp_s() -> void:
	assert_eq(Format.caps("Schließen"), "SCHLIESSEN")


func test_caps_leaves_an_umlaut_alone() -> void:
	assert_eq(Format.caps("Fähigkeiten"), "FÄHIGKEITEN")


# --------------------------------------------------------- m3-screens §10.6


func test_factor_reads_as_a_multiplier() -> void:
	_english()
	assert_eq(Format.factor(1.3), "×1.3")
	assert_eq(Format.factor(0.85), "×0.85", "two places where one would round it away")
	assert_eq(Format.factor(2.0), "×2", "and none where there is nothing to say")


func test_factor_follows_the_locale() -> void:
	_german()
	assert_eq(Format.factor(0.85), "×0,85")


func test_percent_fine_keeps_the_first_decimal() -> void:
	_english()
	assert_eq(Format.percent_fine(0.0042), "0.4%")
	_german()
	assert_eq(Format.percent_fine(0.0042), "0,4 %")


func test_percent_fine_drops_a_decimal_that_is_zero() -> void:
	_english()
	assert_eq(Format.percent_fine(0.25), "25%")
