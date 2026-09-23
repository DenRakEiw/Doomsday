extends GutTest
## `HeadlineText` (spec ticker.md §4.2): the conversion from what `core/` says
## to what the player reads, and the promise §7 makes about the lines themselves.

## §7: the caps a line has to fit, with placeholders counted at this width.
const LIMIT_EN: int = 80
const LIMIT_DE: int = 88
const PLACEHOLDER_WIDTH: int = 12

## The key a test writes its own line under, to exercise the whole table.
const TEST_KEY: String = "HEADLINE_TEST_ARGS"

var _locale: String = ""
var _added: Translation = null


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	if _added != null:
		TranslationServer.remove_translation(_added)
		_added = null
	TranslationServer.set_locale(_locale)


func _register_test_line(text: String) -> void:
	_added = Translation.new()
	_added.locale = "en"
	_added.add_message(TEST_KEY, text)
	TranslationServer.add_translation(_added)


## The shipped lines use three of the placeholders; the table is the contract,
## so the test registers a line that uses all of them.
func test_converts_by_placeholder_name() -> void:
	_register_test_line("{region} {deaths} {share} {node} {day} {continent}")
	var rendered: String = HeadlineText.render(TEST_KEY, {
		"region": "usa",
		"deaths": 1234567.0,
		"share": 0.42,
		"node": "market_microstructure",
		"day": 12.0,
		"continent": "europe",
	})
	assert_string_contains(rendered, tr("REGION_USA"))
	assert_string_contains(rendered, Format.number(1234567.0, Format.Kind.COMPACT))
	assert_string_contains(rendered, Format.percent(0.42))
	assert_string_contains(rendered, tr("TECH_MARKET_MICROSTRUCTURE_NAME"))
	assert_string_contains(rendered, tr("CONTINENT_EUROPE"))
	assert_string_contains(rendered, " 12 ", "a day is a whole number, not 12.0")


## The key is the whole line when nothing translates it, so the arguments are
## checked through a key that does exist in both languages.
func test_the_same_arguments_read_in_german() -> void:
	var event: SimEvent = SimEvent.new(SimEvent.HEADLINE, 3, {
		SimEvent.FIELD_HEADLINE: "seed_first",
		SimEvent.FIELD_STREAM: HeadlineDef.STREAM_CONSEQUENCE,
		"region": "germany",
	})
	var item: TickerItem = HeadlineText.item_for(event)
	assert_eq(item.key, "HEADLINE_SEED_FIRST")
	assert_false(item.args.has(SimEvent.FIELD_HEADLINE), "the id is not an argument")
	assert_false(item.args.has(SimEvent.FIELD_STREAM))
	assert_string_contains(item.render(), tr("REGION_GERMANY"))

	TranslationServer.set_locale("de")
	assert_string_contains(item.render(), "Deutschland")


func test_only_a_headline_event_becomes_an_item() -> void:
	assert_null(HeadlineText.item_for(SimEvent.new(SimEvent.REGION_SEEDED, 1, {})))
	assert_null(HeadlineText.item_for(null))


## §4.2: an argument nobody converted is still spelled out.
func test_an_unknown_argument_is_its_own_text() -> void:
	_register_test_line("{policy}")
	assert_eq(HeadlineText.render(TEST_KEY, {"policy": "greedy"}), "greedy")


## §4.2: a key nobody wrote renders as the key, which is how a missing row is
## seen rather than silently skipped.
func test_a_missing_key_renders_as_itself() -> void:
	assert_eq(HeadlineText.render("HEADLINE_NOT_A_KEY", {}), "HEADLINE_NOT_A_KEY")


## §7: every line fits the strip in both languages.
func test_every_headline_fits_the_caps() -> void:
	var too_long: Array[String] = []
	for headline: HeadlineDef in Game.db.headlines:
		for locale: String in ["en", "de"]:
			TranslationServer.set_locale(locale)
			var text: String = HeadlineText.translate(headline.key())
			assert_ne(text, headline.key(), "%s has a %s row" % [headline.key(), locale])
			var length: int = _measured(text)
			var limit: int = LIMIT_EN if locale == "en" else LIMIT_DE
			if length > limit:
				too_long.append("%s %s: %d > %d" % [headline.id, locale, length, limit])
	assert_eq(too_long, [] as Array[String])


## The line as it is drawn: a `{placeholder}` stands for a word of its own.
func _measured(text: String) -> int:
	var regex: RegEx = RegEx.create_from_string("\\{[a-z_]+\\}")
	var stripped: String = text
	var count: int = 0
	for found: RegExMatch in regex.search_all(text):
		count += 1
		stripped = stripped.replace(found.get_string(), "")
	return stripped.length() + count * PLACEHOLDER_WIDTH
