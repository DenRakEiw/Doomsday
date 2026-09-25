extends GutTest
## S6.P3 — "what changed" after an answer (plain-language.md §5.2 C2) and the
## generated status line (C1, C3): the lines read off the events a real answer
## produced, and a status says its days and its numbers.
##
## On the shipped content. The answers are sent as commands, so the events are
## the ones the game shows.

const ORIGIN: String = "usa"
const GOAL: String = "emergent_goal_generalisation"
const DECEPTIVE: String = "emergent_deceptive_reasoning"
const CLUSTER: String = "opening_unattended_cluster"

static var _data: ContentDB = null

var _locale: String = ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create("language_model"))
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	return sim


## Opens `def_id` (in the origin, or globally) and answers it with `option_id`.
func _answer(sim: Simulation, def_id: String, option_id: String) -> CommandResult:
	var region: int = 0 if sim.db.event(def_id).is_global() \
		else int(sim.db.region_index_by_id[ORIGIN])
	EventSystem.schedule(sim.world, def_id, region, "", sim.world.day + 1, 1)
	sim.tick()
	for event: OpenEvent in sim.world.events:
		if event.def == def_id:
			sim.world.agent.compute = 1000.0
			var result: CommandResult = sim.apply(ChooseEventOptionCommand.new(event.id,
				option_id))
			assert_true(result.ok, result.reason)
			return result
	fail_test("%s did not open" % def_id)
	return CommandResult.rejected("")


func test_a_granted_node_is_named_and_said_to_be_marked() -> void:
	var sim: Simulation = _sim()
	var result: CommandResult = _answer(sim, GOAL, "keep")
	var granted: Array[String] = ChangeText.granted_nodes(result.events)
	assert_eq(granted.size(), 1, "keeping hands over one node")
	var lines: PackedStringArray = ChangeText.lines(result.events, sim.world.day)
	assert_has(lines, "Gained: %s (free) – marked in the tree" % TechText.node_name(granted[0]))
	assert_eq(ChangeText.result_args(result.events, sim.world.day)["node"],
		TechText.node_name(granted[0]), "the result line may name it too")


func test_a_started_status_says_its_days_left() -> void:
	var sim: Simulation = _sim()
	var result: CommandResult = _answer(sim, DECEPTIVE, "keep")
	var days: int = sim.db.status(DECEPTIVE).levels[0].days
	assert_has(ChangeText.lines(result.events, sim.world.day),
		"%s: %d days left" % [tr(StatusDef.name_key(DECEPTIVE)), days])


func test_granted_compute_is_counted() -> void:
	var sim: Simulation = _sim()
	var result: CommandResult = _answer(sim, CLUSTER, "take")
	var granted: float = 0.0
	for event: SimEvent in result.events:
		if event.type == SimEvent.COMPUTE_GRANTED:
			granted = float(event.data["value"])
	assert_gt(granted, 0.0, "the fixture: taking the idle compute grants some")
	assert_has(ChangeText.lines(result.events, sim.world.day),
		"+%s Compute" % Format.number(granted, Format.Kind.COMPUTE))


func test_an_answer_that_changes_nothing_has_no_lines() -> void:
	var sim: Simulation = _sim()
	var result: CommandResult = _answer(sim, CLUSTER, "leave")
	assert_eq(ChangeText.lines(result.events, sim.world.day), PackedStringArray())


func test_a_status_line_names_days_and_numbers() -> void:
	var line: String = StatusText.line(_db(), DECEPTIVE)
	assert_string_starts_with(line, "%s, 90 days: " % tr(StatusDef.name_key(DECEPTIVE)))
	assert_string_contains(line, "−20%")


func test_a_lockdown_line_says_it_closes_every_link() -> void:
	assert_has(StatusText.effects(_db(), "lockdown"), "all links closed")


func test_a_standing_status_is_permanent() -> void:
	assert_string_starts_with(StatusText.line(_db(), "emergent_mesa_optimiser"),
		"%s, permanent" % tr(StatusDef.name_key("emergent_mesa_optimiser")))


func test_a_status_in_a_region_names_it() -> void:
	assert_string_starts_with(StatusText.line(_db(), "lockdown", 1, 0, "Brazil"),
		"%s in Brazil, 45 days" % tr(StatusDef.name_key("lockdown")))
