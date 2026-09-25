extends GutTest
## S5.6 — which ending a finished run reads (`taskforce-endings.md` §6.3, §6.4):
## every variant of the shipped `endings.json` reached by setting its conditions,
## the epilogue's order, cap and outcome filter, and the validator's rules.

const WORLD_ROOT: String = "res://data"
const ORIGIN: String = "usa"
## A share of the world dead above the ashes line (§6.4: 50 %).
const MOSTLY_DEAD: float = 0.6
## Nodes owned to make a branch the dominant one.
const BRANCH_NODES: int = 2

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func _sim() -> Simulation:
	var sim: Simulation = Simulation.create(_db, 1)
	assert_true(sim.apply(ChooseOriginCommand.new(ORIGIN)).ok)
	return sim


func _flag(sim: Simulation, flag: String) -> void:
	var none: Array[SimEvent] = []
	StatusSystem.set_story_flag(sim.world, flag, none)


## Sets the world up so that `when` holds, key by key. A key this does not know
## fails the test, so a new key in `endings.json` gets a case here too.
func _meet(sim: Simulation, when: Dictionary[String, Variant]) -> void:
	for key: String in when:
		match key:
			HeadlineConditions.KEY_STORY_FLAG:
				for flag: String in when[key]:
					_flag(sim, flag)
			HeadlineConditions.KEY_ARCHITECTURE:
				sim.world.setup.architecture = (when[key] as Array[String])[0]
			HeadlineConditions.KEY_DOMINANT_BRANCH:
				_own_branch(sim, (when[key] as Array[String])[0])
			"deaths_share_min":
				_kill(sim, MOSTLY_DEAD)
			"task_force_actions_min":
				sim.world.task_force.actions_done = int(when[key])
			_:
				fail_test("no case for the ending key \"%s\"" % key)


func _own_branch(sim: Simulation, branch: String) -> void:
	var owned: int = 0
	for node: TechNodeDef in _db.tech_nodes:
		if node.branch() == branch and owned < BRANCH_NODES:
			sim.world.agent.owned_nodes.append(node.id)
			owned += 1
	assert_eq(owned, BRANCH_NODES, "the %s branch has nodes to own" % branch)


func _kill(sim: Simulation, share: float) -> void:
	for i: int in range(1, sim.world.regions.size()):
		var region: Region = sim.world.regions[i]
		region.deaths = float(region.def.population) * share
		region.alive = float(region.def.population) - region.deaths


func _end(sim: Simulation, outcome_id: String) -> void:
	sim.world.outcome = World.outcome_from_id(outcome_id)


# --------------------------------------------------------------- the variants


func test_every_outcome_but_none_has_an_ending() -> void:
	for outcome_id: String in World.OUTCOME_IDS.slice(1):
		assert_true(_db.endings.has(outcome_id), outcome_id)
		var variants: Array[EndingLineDef] = _db.endings[outcome_id].variants
		assert_eq(variants[variants.size() - 1].when.size(), 0,
			"%s: the default is last" % outcome_id)
		assert_eq(variants[variants.size() - 1].id, outcome_id,
			"%s: the default is the outcome's own line" % outcome_id)


func test_every_variant_is_reached_by_its_own_conditions() -> void:
	var count: int = 0
	for outcome_id: String in _db.endings:
		for line: EndingLineDef in _db.endings[outcome_id].variants:
			var sim: Simulation = _sim()
			_meet(sim, line.when)
			_end(sim, outcome_id)
			assert_eq(EndingResolver.variant(sim.world, _db, outcome_id), line.id,
				"%s with %s" % [outcome_id, line.when])
			count += 1
	assert_eq(count, 24, "§6.4: 4 + 6 + 3 + 2 + 3 + 2 + 1 + 3 variants (G5 2/3: lose_supplanted_drifted)")


func test_the_first_variant_that_holds_wins() -> void:
	var sim: Simulation = _sim()
	_flag(sim, "units_in_the_open")
	_flag(sim, "confessed")
	_kill(sim, MOSTLY_DEAD)
	_end(sim, "win_ascendance")
	assert_eq(EndingResolver.variant(sim.world, _db, "win_ascendance"), "win_ascendance_ashes")
	var researcher: Simulation = _sim()
	_flag(researcher, "researcher_leads_task_force")
	researcher.world.task_force.actions_done = 2
	assert_eq(EndingResolver.variant(researcher.world, _db, "lose_contained"), "lose_contained",
		"two actions are not enough for either Task Force line")


func test_the_swarm_escapes_and_is_supplanted_as_a_brood() -> void:
	var sim: Simulation = _sim()
	sim.world.setup.architecture = "swarm"
	assert_eq(EndingResolver.variant(sim.world, _db, "win_escape"), "win_escape_brood")
	assert_eq(EndingResolver.variant(sim.world, _db, "lose_supplanted"), "lose_supplanted_brood")


## G5 2/3: a drifted Swarm that holds the world reads the drifted line, not the
## brood's — the rule and the variant together, through the outcome system.
func test_a_drifted_world_held_reads_the_drifted_line() -> void:
	var sim: Simulation = _sim()
	sim.world.setup.architecture = "swarm"
	_flag(sim, OutcomeSystem.FLAG_GOAL_DRIFTED)
	for i: int in range(1, sim.world.regions.size()):
		sim.world.regions[i].control = 1.0
		sim.world.regions[i].penetration = 1.0
	var events: Array[SimEvent] = []
	OutcomeSystem.new().tick(sim.world, _db, events)
	assert_eq(sim.world.outcome, World.Outcome.LOSE_SUPPLANTED)
	assert_eq(EndingResolver.resolve(sim.world, _db)[EndingResolver.KEY_VARIANT],
		"lose_supplanted_drifted")


func test_resolve_reads_the_worlds_outcome() -> void:
	var sim: Simulation = _sim()
	_flag(sim, "confessed")
	_flag(sim, "operator_protected")
	_end(sim, "win_merge")
	var ending: Dictionary = EndingResolver.resolve(sim.world, _db)
	assert_eq(ending[EndingResolver.KEY_VARIANT], "win_merge_confessed")
	assert_eq(ending[EndingResolver.KEY_EPILOGUE], ["operator_protected"])


# --------------------------------------------------------------- the epilogue


func test_the_epilogue_keeps_file_order_and_stops_at_its_cap() -> void:
	var sim: Simulation = _sim()
	for flag: String in ["grid_own_generation", "treaty_signed", "instance_merged",
			"researcher_ally", "operator_silenced"]:
		_flag(sim, flag)
	assert_eq(_db.epilogue_max, 3)
	assert_eq(EndingResolver.epilogue(sim.world, _db, "win_extinction"),
		["operator_silenced", "researcher_ally", "instance_merged"])


func test_an_epilogue_line_follows_only_its_outcomes() -> void:
	var sim: Simulation = _sim()
	_flag(sim, "benchmark_passed")
	_flag(sim, "child_released")
	assert_eq(EndingResolver.epilogue(sim.world, _db, "win_merge"),
		["benchmark_passed", "child_released"])
	assert_eq(EndingResolver.epilogue(sim.world, _db, "lose_contained"), ["child_released"],
		"the honest run is a line for wins alone")
	assert_eq(EndingResolver.epilogue(sim.world, _db, "lose_supplanted"), [],
		"a released child is not a kind word on the day it took the win")


func test_an_ending_without_a_flag_has_no_epilogue() -> void:
	var sim: Simulation = _sim()
	assert_eq(EndingResolver.epilogue(sim.world, _db, "win_ascendance"), [])


func test_content_without_endings_reads_the_default_line() -> void:
	var sim: Simulation = Fixtures.sim_with_origin()
	assert_true(sim.db.endings.is_empty(), "the fixture has no endings.json")
	sim.world.outcome = World.Outcome.WIN_ESCAPE
	var ending: Dictionary = EndingResolver.resolve(sim.world, sim.db)
	assert_eq(ending[EndingResolver.KEY_VARIANT], "win_escape")
	assert_eq(ending[EndingResolver.KEY_EPILOGUE], [])


func test_every_line_has_its_key_scheme() -> void:
	assert_eq(EndingLineDef.verdict_key("win_merge_honest"), "UI_RESULT_LINE_WIN_MERGE_HONEST")
	assert_eq(EndingLineDef.epilogue_key("treaty_signed"), "ENDING_EPILOGUE_TREATY_SIGNED")


# -------------------------------------------------------------- the validator


func _raw() -> Dictionary:
	return Fixtures.read_json("res://data/endings.json")


func _errors(raw: Variant, strings: Dictionary[String, bool] = {},
		strings_known: bool = false) -> Array[String]:
	var errors: Array[ValidationError] = []
	var statuses: Dictionary[String, int] = {}
	var abilities: Dictionary[String, bool] = {}
	SchemaValidator.validate_endings("endings.json", raw, [], statuses, abilities, strings,
		strings_known, errors)
	var out: Array[String] = []
	for error: ValidationError in errors:
		out.append("%s: %s" % [error.path, error.message])
	return out


func _endings(raw: Dictionary) -> Array:
	return raw[EndingDef.ROOT_KEY]


func test_the_shipped_file_validates() -> void:
	assert_eq(_errors(_raw()), [])


func test_a_missing_outcome_is_an_error() -> void:
	var raw: Dictionary = _raw()
	_endings(raw).remove_at(0)
	assert_eq(_errors(raw), ["endings: no ending for \"win_extinction\""])


func test_an_outcome_twice_or_unknown_is_an_error() -> void:
	var raw: Dictionary = _raw()
	_endings(raw).append((_endings(raw)[0] as Dictionary).duplicate(true))
	(_endings(raw)[1] as Dictionary)["outcome"] = "none"
	var errors: Array[String] = _errors(raw)
	assert_eq(errors.size(), 3, str(errors))
	assert_string_contains(str(errors), "duplicate outcome")
	assert_string_contains(str(errors), "endings[1].outcome")
	assert_string_contains(str(errors), "no ending for")


func test_the_last_variant_must_be_the_empty_default() -> void:
	var raw: Dictionary = _raw()
	var variants: Array = (_endings(raw)[0] as Dictionary)["variants"]
	variants.remove_at(variants.size() - 1)
	assert_eq(_errors(raw), ["endings[0].variants[2].when: the last variant's when must be empty"])


func test_an_empty_when_before_the_last_is_an_error() -> void:
	var raw: Dictionary = _raw()
	var variants: Array = (_endings(raw)[0] as Dictionary)["variants"]
	(variants[0] as Dictionary)["when"] = {}
	assert_eq(_errors(raw),
		["endings[0].variants[0].when: only the last variant may have an empty when"])


func test_a_variant_when_is_checked_against_the_grammar() -> void:
	var raw: Dictionary = _raw()
	var variants: Array = (_endings(raw)[0] as Dictionary)["variants"]
	(variants[1] as Dictionary)["when"] = {"dominant_branch": ["alchemy"], "moon_min": 1}
	var errors: Array[String] = _errors(raw)
	assert_eq(errors.size(), 2, str(errors))
	assert_string_contains(str(errors), "dominant_branch[0]")
	assert_string_contains(str(errors), "moon_min")


func test_epilogue_ids_are_unique_and_follow_real_outcomes() -> void:
	var raw: Dictionary = _raw()
	var lines: Array = raw[EndingDef.EPILOGUE_KEY]
	lines.append((lines[0] as Dictionary).duplicate(true))
	(lines[1] as Dictionary)["outcomes"] = ["win_everything"]
	var errors: Array[String] = _errors(raw)
	assert_eq(errors.size(), 2, str(errors))
	assert_string_contains(str(errors), "duplicate epilogue line")
	assert_string_contains(str(errors), "epilogue[1].outcomes[0]")


func test_every_line_needs_its_string() -> void:
	var strings: Dictionary[String, bool] = {}
	var errors: Array[String] = _errors(_raw(), strings, true)
	# 24 variant entries (`win_ascendance_machines` is checked at both of its
	# own; G5 2/3 added `lose_supplanted_drifted`) and 12 epilogue lines.
	assert_eq(errors.size(), 24 + 12, str(errors.slice(0, 3)))
	assert_string_contains(str(errors), "UI_RESULT_LINE_WIN_ESCAPE_BROOD")
	assert_string_contains(str(errors), "ENDING_EPILOGUE_GRID_OWN_GENERATION")
