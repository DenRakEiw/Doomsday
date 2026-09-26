extends GutTest
## S6.12 — the answer cache (docs/specs/benchmark.md §9) in a directory of its
## own under `user://`; S6.12c — the request's basis (§17.7): a chat key is what
## it was, a choice key follows its plan and attempt.

const Cache := preload("res://tools/bench/bench_cache.gd")
const Harness := preload("res://tools/sim_harness.gd")
const ROOT: String = "user://test_bench/cache"
const MODEL: String = "vendor/model"
const PARAMS: Dictionary = {"temperature": 0.0, "max_completion_tokens": 1200}
## `Cache.key(MODEL, PARAMS, 1, 1, messages("brief", "digest"))` computed before
## the basis change (S6.12c), with the S6.12 code: every chat cache file keeps
## its key.
const PINNED_CHAT_KEY: String = "75c7ca56418e02ccffc42b75ddfc572501fe39f5096dad87ce7f1a72f7ef7650"
const CHOICE_PARAMS: Dictionary = {"choice_version": 1,
	"max_picks": {"buy": 3, "use": 2, "wake": 2, "sleep": 2}}

var _cache: Cache = null


func before_each() -> void:
	_clear(ROOT)
	_cache = Cache.new(ROOT)


func after_all() -> void:
	_clear(ROOT)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_clear(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


func _messages(extra: String = "") -> Array[Dictionary]:
	return BenchPrompt.messages("brief", "digest", extra)


func _basis(extra: String = "") -> Dictionary:
	return Cache.chat_basis(_messages(extra))


func _plan(situation: String = "situation", instructions: String = "Which?") -> BenchChoicePlan:
	var plan: BenchChoicePlan = BenchChoicePlan.new()
	plan.state = {"rules": "rules", "situation": situation}
	plan.questions = {"stance": {"type": "choice", "instructions": instructions,
		"criteria": {"spread": "Spread", "wait": "Wait"}}}
	plan.keys = {"stance": ["spread", "wait"]}
	return plan


func _value() -> Dictionary:
	var answer: BenchAnswer = BenchAnswer.parse(
		"{\"stance\": \"spread\", \"actions\": [{\"do\": \"origin\", \"region\": \"usa\"}]}", 12)
	return {"answer": answer.to_cache(), "tokens_in": 100, "tokens_out": 10, "cost_usd": 0.01,
		"finish": "stop"}


func test_a_miss_then_a_write_then_a_hit() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _basis())
	assert_eq(_cache.read(MODEL, key), {})
	assert_true(_cache.write(MODEL, key, _value()))
	var hit: Dictionary = _cache.read(MODEL, key)
	assert_false(hit.is_empty())
	var answer: BenchAnswer = BenchAnswer.from_cache(hit["answer"])
	assert_not_null(answer)
	assert_eq(answer.actions[0].compact(), "origin usa")
	assert_eq(int(hit["tokens_in"]), 100)


func test_the_path_is_sharded_by_the_model_slug_and_the_key() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _basis())
	assert_eq(_cache.path_for(MODEL, key), "%s/vendor--model/%s/%s.json" % [ROOT,
		key.substr(0, 2), key])


func test_a_changed_param_prompt_version_or_retry_is_another_key() -> void:
	var base: String = Cache.key(MODEL, PARAMS, 1, 1, _basis())
	assert_ne(Cache.key(MODEL, {"temperature": 0.5, "max_completion_tokens": 1200}, 1, 1,
		_basis()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 2, 1, _basis()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 1, 2, _basis()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 1, 1, _basis("bad_json")), base)
	assert_ne(Cache.key("other/model", PARAMS, 1, 1, _basis()), base)
	assert_eq(Cache.key(MODEL, PARAMS, 1, 1, _basis()), base, "and the same is the same")


func test_a_corrupt_file_is_a_miss() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _basis())
	_cache.write(MODEL, key, _value())
	var file: FileAccess = FileAccess.open(_cache.path_for(MODEL, key), FileAccess.WRITE)
	file.store_string("{\"answer\": {\"stance\": 3}}")
	file.close()
	assert_eq(_cache.read(MODEL, key), {})
	file = FileAccess.open(_cache.path_for(MODEL, key), FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	assert_eq(_cache.read(MODEL, key), {})
	assert_true(_cache.write(MODEL, key, _value()), "and it is overwritten")
	assert_false(_cache.read(MODEL, key).is_empty())


func test_the_stored_value_holds_no_text() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _basis())
	_cache.write(MODEL, key, _value())
	var stored: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_cache.path_for(MODEL, key)))
	assert_false(stored.has("text"))
	assert_false((stored["answer"] as Dictionary).has("text"))


func test_the_hooks_read_and_write_and_fresh_skips_the_reads() -> void:
	var hooks: Dictionary = _cache.hooks(MODEL, PARAMS, 1, 1, true)
	var writer: Callable = hooks["write"]
	var reader: Callable = hooks["read"]
	writer.call(_basis(), _value())
	assert_false((reader.call(_basis()) as Dictionary).is_empty())
	var fresh: Dictionary = _cache.hooks(MODEL, PARAMS, 1, 1, false)
	assert_false((fresh["read"] as Callable).is_valid())
	assert_true((fresh["write"] as Callable).is_valid())


func test_a_chat_key_is_unchanged_by_the_basis() -> void:
	assert_eq(Cache.key(MODEL, PARAMS, 1, 1, _basis()), PINNED_CHAT_KEY)


func test_a_choice_basis_differs_by_state_questions_attempt_and_params() -> void:
	var base: String = Cache.key(MODEL, CHOICE_PARAMS, 1, 1, _plan().basis())
	assert_eq(Cache.key(MODEL, CHOICE_PARAMS, 1, 1, _plan().basis()), base, "the same is the same")
	assert_ne(Cache.key(MODEL, CHOICE_PARAMS, 1, 1, _plan("elsewhere").basis()), base, "state")
	assert_ne(Cache.key(MODEL, CHOICE_PARAMS, 1, 1, _plan("situation", "Why?").basis()), base,
		"questions")
	var retry: Dictionary = _plan().basis()
	retry[ModelPolicy.BASIS_ATTEMPT] = 1
	assert_ne(Cache.key(MODEL, CHOICE_PARAMS, 1, 1, retry), base, "attempt")
	var other: Dictionary = CHOICE_PARAMS.duplicate(true)
	other["choice_version"] = 2
	assert_ne(Cache.key(MODEL, other, 1, 1, _plan().basis()), base, "params")


func test_a_choice_value_holds_no_probabilities() -> void:
	var sim: Simulation = Fixtures.sim(1)
	var policy: ModelPolicy = ModelPolicy.new(MockChoiceBackend.new(MockChoiceBackend.MODE_FIRST),
		BenchConfig.load_file(), CHOICE_PARAMS, "en")
	policy.setup(sim.db, Policy.seed_for(1))
	var hooks: Dictionary = _cache.hooks(MODEL, CHOICE_PARAMS, 1, 1, true)
	policy.cache_write = hooks["write"]
	var problems: Array[String] = []
	Harness.advance(sim, policy, 1, false, problems)
	var files: Array[String] = _files(ROOT)
	assert_eq(files.size(), 1, "one decision, one file")
	var text: String = FileAccess.get_file_as_string(files[0])
	assert_false(text.contains("probabilities"))
	var stored: Dictionary = JSON.parse_string(text)
	assert_eq(str(stored["model_version"]), MockChoiceBackend.MODEL_VERSION)
	assert_true(stored.has("confidence"))
	assert_not_null(BenchAnswer.from_cache(stored["answer"]))


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub)))
	for file_name: String in DirAccess.get_files_at(dir):
		out.append(dir.path_join(file_name))
	return out
