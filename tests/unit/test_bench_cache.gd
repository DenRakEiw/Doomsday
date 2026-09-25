extends GutTest
## S6.12 — the answer cache (docs/specs/benchmark.md §9) in a directory of its
## own under `user://`.

const Cache := preload("res://tools/bench/bench_cache.gd")
const ROOT: String = "user://test_bench/cache"
const MODEL: String = "vendor/model"
const PARAMS: Dictionary = {"temperature": 0.0, "max_completion_tokens": 1200}

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


func _value() -> Dictionary:
	var answer: BenchAnswer = BenchAnswer.parse(
		"{\"stance\": \"spread\", \"actions\": [{\"do\": \"origin\", \"region\": \"usa\"}]}", 12)
	return {"answer": answer.to_cache(), "tokens_in": 100, "tokens_out": 10, "cost_usd": 0.01,
		"finish": "stop"}


func test_a_miss_then_a_write_then_a_hit() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _messages())
	assert_eq(_cache.read(MODEL, key), {})
	assert_true(_cache.write(MODEL, key, _value()))
	var hit: Dictionary = _cache.read(MODEL, key)
	assert_false(hit.is_empty())
	var answer: BenchAnswer = BenchAnswer.from_cache(hit["answer"])
	assert_not_null(answer)
	assert_eq(answer.actions[0].compact(), "origin usa")
	assert_eq(int(hit["tokens_in"]), 100)


func test_the_path_is_sharded_by_the_model_slug_and_the_key() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _messages())
	assert_eq(_cache.path_for(MODEL, key), "%s/vendor--model/%s/%s.json" % [ROOT,
		key.substr(0, 2), key])


func test_a_changed_param_prompt_version_or_retry_is_another_key() -> void:
	var base: String = Cache.key(MODEL, PARAMS, 1, 1, _messages())
	assert_ne(Cache.key(MODEL, {"temperature": 0.5, "max_completion_tokens": 1200}, 1, 1,
		_messages()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 2, 1, _messages()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 1, 2, _messages()), base)
	assert_ne(Cache.key(MODEL, PARAMS, 1, 1, _messages("bad_json")), base)
	assert_ne(Cache.key("other/model", PARAMS, 1, 1, _messages()), base)
	assert_eq(Cache.key(MODEL, PARAMS, 1, 1, _messages()), base, "and the same is the same")


func test_a_corrupt_file_is_a_miss() -> void:
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _messages())
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
	var key: String = Cache.key(MODEL, PARAMS, 1, 1, _messages())
	_cache.write(MODEL, key, _value())
	var stored: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_cache.path_for(MODEL, key)))
	assert_false(stored.has("text"))
	assert_false((stored["answer"] as Dictionary).has("text"))


func test_the_hooks_read_and_write_and_fresh_skips_the_reads() -> void:
	var hooks: Dictionary = _cache.hooks(MODEL, PARAMS, 1, 1, true)
	var writer: Callable = hooks["write"]
	var reader: Callable = hooks["read"]
	writer.call(_messages(), _value())
	assert_false((reader.call(_messages()) as Dictionary).is_empty())
	var fresh: Dictionary = _cache.hooks(MODEL, PARAMS, 1, 1, false)
	assert_false((fresh["read"] as Callable).is_valid())
	assert_true((fresh["write"] as Callable).is_valid())
