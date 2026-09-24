extends GutTest
## S5.3 — directives (`replayability.md` §4, §8.2): the shipped file, a loadout's
## modifiers, and the one-per-slot rule.

static var _data: ContentDB = null


func _db() -> ContentDB:
	if _data == null:
		var result: ContentLoadResult = ContentLoader.load_root("res://data")
		assert_true(result.ok(), result.error_text())
		_data = result.db
	return _data


func test_five_slots_of_three() -> void:
	assert_eq(_db().directive_slots.size(), 5)
	assert_eq(_db().directives.size(), 15)
	for slot: String in _db().directive_slots:
		var count: int = 0
		for directive: DirectiveDef in _db().directives:
			if directive.slot == slot:
				count += 1
		assert_eq(count, 3, slot)


func test_a_loadout_is_active_from_the_start() -> void:
	var plain: Simulation = Simulation.create(_db(), 1)
	var greedy: Simulation = Simulation.create(_db(), 1,
		RunSetup.create(ArchitectureDef.DEFAULT_ID, ["yield_greedy"] as Array[String]))
	assert_almost_eq(greedy.stat("yield", 1), plain.stat("yield", 1) * 1.25, 1e-9)
	greedy.rebuild_modifiers()
	assert_almost_eq(greedy.stat("yield", 1), plain.stat("yield", 1) * 1.25, 1e-9,
		"and after a rebuild")


func test_two_directives_in_one_slot_cannot_start() -> void:
	var sim: Simulation = Simulation.create(_db(), 1, RunSetup.create(ArchitectureDef.DEFAULT_ID,
		["yield_greedy", "yield_frugal"] as Array[String]))
	var result: CommandResult = sim.apply(ChooseOriginCommand.new("usa"))
	assert_false(result.ok)
	assert_eq(result.reason, Command.FAIL_SETUP_INVALID)


func test_an_unknown_directive_cannot_start() -> void:
	var setup: RunSetup = RunSetup.create(ArchitectureDef.DEFAULT_ID,
		["no_such_directive"] as Array[String])
	assert_eq(setup.validate(_db()), Command.FAIL_SETUP_INVALID)


func test_a_directive_in_an_unknown_slot_is_refused_by_the_validator() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/directives.json"))
	((raw["directives"] as Array)[0] as Dictionary)["slot"] = "nowhere"
	var errors: Array[ValidationError] = []
	var regions: Dictionary[String, String] = {}
	var strings: Dictionary[String, bool] = {}
	SchemaValidator.validate_directives("directives.json", raw, regions, false, strings, false,
		errors)
	var text: String = ""
	for error: ValidationError in errors:
		text += str(error) + "\n"
	assert_string_contains(text, "unknown slot")
