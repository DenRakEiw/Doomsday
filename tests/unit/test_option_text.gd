extends GutTest
## S6.P3 — the generated line under every event option (plain-language.md §5.2
## C1): every shipped option says something in both languages and names no raw
## key, and the lines of §4.4's examples say what the data says.
##
## On the shipped content, whose options these are.

const ORIGIN: String = "usa"
const LOCALES: Array[String] = ["en", "de"]
## A key that reached the screen untranslated: capitals and underscores (an
## unfilled `{placeholder}` is caught by its brace).
const RAW_KEY: String = "\\b[A-Z][A-Z0-9]*(_[A-Z0-9]+)+\\b"
const DECEPTIVE: String = "emergent_deceptive_reasoning"
const GOAL: String = "emergent_goal_generalisation"
const LOCKDOWN: String = "cm_lockdown"
const DISCLOSURE: String = "cm_disclosure_land"
const CLUSTER: String = "opening_unattended_cluster"

static var _data: ContentDB = null

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim(architecture: String = "language_model") -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create(architecture))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new(ORIGIN))
	assert_true(result.ok, result.reason)
	return sim


func _line(sim: Simulation, def_id: String, option_id: String) -> String:
	var def: EventDef = sim.db.event(def_id)
	return OptionText.line(sim, def, def.option(option_id))


func test_every_shipped_option_has_a_line_in_both_languages() -> void:
	var sim: Simulation = _sim()
	var raw: RegEx = RegEx.create_from_string(RAW_KEY)
	var bad: Array[String] = []
	var count: int = 0
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		for def: EventDef in sim.db.events:
			for option: EventOptionDef in def.options:
				count += 1
				var line: String = OptionText.line(sim, def, option)
				if line.strip_edges().is_empty():
					bad.append("%s %s/%s: empty" % [locale, def.id, option.id])
				elif raw.search(line) != null or line.contains("{"):
					bad.append("%s %s/%s: %s" % [locale, def.id, option.id, line])
	assert_eq(bad, [] as Array[String])
	assert_eq(count, 172 * LOCALES.size(), "every option of the 68 events, twice")


func test_keeping_deceptive_reasoning_names_the_status_its_days_and_its_number() -> void:
	TranslationServer.set_locale("en")
	var line: String = _line(_sim(), DECEPTIVE, "keep")
	assert_string_starts_with(line, "Free · ")
	assert_string_contains(line, "90 days")
	assert_string_contains(line, "−20%")


func test_suppressing_says_the_price_rises_and_nothing_else_happens() -> void:
	TranslationServer.set_locale("de")
	var sim: Simulation = _sim()
	var def: EventDef = sim.db.event(DECEPTIVE)
	var price: String = Format.number(sim.option_cost(def.option("suppress")),
		Format.Kind.COMPUTE)
	assert_eq(_line(sim, DECEPTIVE, "suppress"),
		"Kostet %s (steigt jedes Mal) · sonst keine Wirkung" % price)


func test_goal_generalisation_says_a_node_is_given() -> void:
	TranslationServer.set_locale("en")
	assert_string_contains(_line(_sim(), GOAL, "keep"),
		"One node of your trees becomes yours for free")


func test_a_counter_move_says_whether_its_status_lands() -> void:
	TranslationServer.set_locale("en")
	var sim: Simulation = _sim()
	var status_name: String = tr(StatusDef.name_key("lockdown"))
	assert_string_contains(_line(sim, LOCKDOWN, "ride"), "%s takes effect" % status_name)
	assert_string_contains(_line(sim, LOCKDOWN, "lobby"), "%s is prevented" % status_name)


func test_a_shorter_status_names_both_lengths() -> void:
	TranslationServer.set_locale("de")
	var sim: Simulation = _sim()
	var option: EventOptionDef = sim.db.event(DISCLOSURE).option("patch")
	assert_gt(option.status_days, 0, "the fixture: patching shortens the disclosure")
	var base: int = sim.db.status("disclosure_land").levels[0].days
	assert_string_contains(_line(sim, DISCLOSURE, "patch"),
		"dauert nur %d statt %d Tage" % [option.status_days, base])


func test_a_roll_reads_as_a_risk_with_its_chance() -> void:
	TranslationServer.set_locale("en")
	var sim: Simulation = _sim()
	var option: EventOptionDef = sim.db.event(CLUSTER).option("seed")
	assert_false(option.chance.is_empty(), "the fixture: reaching a neighbour is a gamble")
	assert_string_contains(_line(sim, CLUSTER, "seed"),
		"Risk %s: " % Format.percent(option.chance[0].p))


func test_a_free_answer_with_no_effect_says_nothing_happens() -> void:
	TranslationServer.set_locale("en")
	assert_eq(_line(_sim(), CLUSTER, "leave"), "Nothing happens")


func test_on_the_swarm_an_answer_says_which_way_the_drift_goes() -> void:
	TranslationServer.set_locale("en")
	var sim: Simulation = _sim("swarm")
	var kept: String = Format.number(sim.db.balance.drift_per_kept, Format.Kind.PLAIN)
	var pulled: String = Format.number(sim.db.balance.drift_per_suppressed, Format.Kind.PLAIN)
	assert_string_contains(_line(sim, DECEPTIVE, "keep"), "Drift +%s" % kept)
	assert_string_contains(_line(sim, DECEPTIVE, "suppress"), "Drift −%s" % pulled)


func test_off_the_swarm_no_line_names_drift() -> void:
	TranslationServer.set_locale("en")
	assert_false(_line(_sim(), DECEPTIVE, "keep").contains("Drift"))
