extends GutTest
## S6.12 — the words a model reads (docs/specs/benchmark.md §5, §6.3, §6.4) on the
## real content, in English and German.

const Harness := preload("res://tools/sim_harness.gd")

var _db: ContentDB = null
var _config: BenchConfig = null
var _setup: RunSetup = null
var _locale: String = ""


func before_all() -> void:
	_db = ContentLoader.load_root("res://data").db
	_config = BenchConfig.load_file()
	_setup = RunSetup.from_dict(_config.setup)


func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func _unfilled(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for hit: RegExMatch in RegEx.create_from_string(StringTable.PLACEHOLDER_PATTERN).search_all(text):
		out.append(hit.get_string())
	return out


## A run some way in: an origin, days of greedy play, an open event — so that the
## digest has regions, offers, abilities, events and a log to write.
func _sim_mid_run() -> Simulation:
	var sim: Simulation = Simulation.create(_db, 1001, _setup)
	var policy: Policy = Policy.create(GreedyPolicy.ID)
	policy.setup(_db, Policy.seed_for(1001))
	var problems: Array[String] = []
	Harness.advance(sim, policy, 150, false, problems)
	return sim


func _memory_with_feedback() -> Dictionary:
	var memory: Dictionary = BenchDigest.new_memory()
	memory[BenchDigest.MEMORY_DECISION] = 4
	memory[BenchDigest.MEMORY_LAST_DAY] = 120
	var feedback: BenchDecision = BenchDecision.new()
	feedback.day = 120
	feedback.stance = "spread"
	feedback.actions = 3
	feedback.done = 1
	feedback.refused.append({"action": "buy nothing_here", "reason": Command.FAIL_UNKNOWN_NODE})
	memory[BenchDigest.MEMORY_FEEDBACK] = feedback
	return memory


func test_the_brief_names_every_region_node_ability_and_stance_and_the_example() -> void:
	var brief: String = BenchPrompt.brief(_db, _setup, _config)
	for i: int in range(1, _db.regions.size()):
		assert_string_contains(brief, "\n" + _db.regions[i].id + ": ")
	for node: TechNodeDef in _db.tech_nodes:
		assert_string_contains(brief, "\n" + node.id + ": ")
	for ability: AbilityDef in _db.abilities:
		assert_string_contains(brief, "\n" + ability.id + ": ")
	for stance: String in BenchAnswer.STANCES:
		assert_string_contains(brief, "- " + stance + ": ")
	assert_string_contains(brief, BenchPrompt.EXAMPLE)
	assert_eq(_unfilled(brief.replace(BenchPrompt.EXAMPLE, "")), PackedStringArray())


func test_the_brief_is_the_same_for_two_seeds_of_one_setup() -> void:
	var first: String = BenchPrompt.brief(_db, _setup, _config)
	Simulation.create(_db, 1002, _setup)
	assert_eq(BenchPrompt.brief(_db, _setup, _config), first)


func test_the_brief_fills_every_placeholder_in_german() -> void:
	TranslationServer.set_locale("de")
	var brief: String = BenchPrompt.brief(_db, _setup, _config)
	assert_eq(_unfilled(brief.replace(BenchPrompt.EXAMPLE, "")), PackedStringArray())
	assert_string_contains(brief, "Die Welt.")


func test_the_digest_fills_every_placeholder_in_both_languages() -> void:
	var fresh: Simulation = Simulation.create(_db, 1001, _setup)
	var sim: Simulation = _sim_mid_run()
	for locale: String in ["en", "de"]:
		TranslationServer.set_locale(locale)
		var first: String = BenchPrompt.digest_text(
			BenchDigest.build(fresh, BenchDigest.new_memory(), _config), _db)
		assert_eq(_unfilled(first), PackedStringArray(), locale + " day 0")
		var later: String = BenchPrompt.digest_text(
			BenchDigest.build(sim, _memory_with_feedback(), _config), _db)
		assert_eq(_unfilled(later), PackedStringArray(), locale + " mid-run")
		assert_string_contains(later, "buy nothing_here")


func test_the_first_digest_has_no_log_and_no_feedback() -> void:
	var sim: Simulation = Simulation.create(_db, 1001, _setup)
	var text: String = BenchPrompt.digest_text(
		BenchDigest.build(sim, BenchDigest.new_memory(), _config), _db)
	assert_false(text.contains(TechText.tr_key("BENCH_DIGEST_LOG_NONE")))
	assert_false(text.contains(TechText.tr_key("BENCH_DIGEST_LOG")))
	assert_string_contains(text, TechText.tr_key("BENCH_DIGEST_ASK"))


func test_messages_are_two_and_three_with_a_retry_and_never_carry_the_last_answer() -> void:
	var two: Array[Dictionary] = BenchPrompt.messages("brief", "digest")
	assert_eq(two.size(), 2)
	assert_eq(str(two[0]["role"]), "system")
	assert_eq(str(two[1]["content"]), "digest")
	var three: Array[Dictionary] = BenchPrompt.messages("brief", "digest", "bad_json")
	assert_eq(three.size(), 3)
	assert_eq(str(three[2]["role"]), "user")
	assert_string_contains(str(three[2]["content"]), "bad_json")
	for message: Dictionary in three:
		assert_ne(str(message["role"]), "assistant")


func test_the_example_names_real_ids() -> void:
	var example: Dictionary = JSON.parse_string(BenchPrompt.EXAMPLE)
	for entry: Variant in example["actions"]:
		var action: Dictionary = entry
		if action.has("region"):
			assert_true(_db.region_index_by_id.has(str(action["region"])), str(action["region"]))
		if action.has("node"):
			assert_not_null(_db.tech(str(action["node"])), str(action["node"]))
		if action.has("ability"):
			assert_not_null(_db.ability(str(action["ability"])), str(action["ability"]))
	assert_true(_db.tech("market_microstructure").deploys(), "the example places it")
	assert_true(_db.ability("harvest").targets_region())
	assert_false(_db.ability("pause").targets_region())
	var audit: EventDef = _db.event("cm_audit")
	assert_not_null(audit)
	assert_eq(audit.faction, "ai_labs")
	assert_not_null(audit.option("sandbag"), "sandbag is an option of the AI Labs' audit")


func test_every_key_built_at_run_time_exists_in_both_languages_alike() -> void:
	var duplicates: Array[String] = []
	var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
		duplicates)
	assert_eq(BenchPrompt.KEYS.size(), 20)
	for key: String in BenchPrompt.KEYS:
		assert_true(table.has(key), key)
		if table.has(key):
			var row: PackedStringArray = table[key]
			assert_false(row[StringTable.COLUMN_EN].is_empty() or row[StringTable.COLUMN_DE].is_empty(),
				key)
			assert_eq(StringTable.placeholders(row[StringTable.COLUMN_EN]),
				StringTable.placeholders(row[StringTable.COLUMN_DE]), key)
