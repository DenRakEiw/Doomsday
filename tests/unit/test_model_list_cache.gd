extends GutTest
## S6.12g — `ModelListCache` (docs/specs/benchmark.md §19.8 item 4): the model
## list is kept only when it is the list, and is fresh for the given age.

const FIXTURE: String = "res://tests/fixtures/bench/openrouter_models.json"
const DIR: String = "user://test_model_list_cache/"

var _cache: ModelListCache = null


func before_each() -> void:
	Fixtures.remove_root(DIR)
	_cache = ModelListCache.new()
	_cache.dir = DIR


func after_all() -> void:
	Fixtures.remove_root(DIR)


func test_nothing_cached_reads_empty_and_is_not_fresh() -> void:
	assert_eq(_cache.read(), "")
	assert_false(_cache.is_fresh(86400, int(Time.get_unix_time_from_system())))


func test_the_list_is_kept_and_fresh_within_its_age() -> void:
	var body: String = FileAccess.get_file_as_string(FIXTURE)
	assert_true(_cache.write(body))
	assert_eq(_cache.read(), body)
	var now: int = int(Time.get_unix_time_from_system())
	assert_true(_cache.is_fresh(86400, now))
	assert_false(_cache.is_fresh(86400, now + 86400 + 1))


func test_a_body_that_is_not_the_list_is_not_kept() -> void:
	assert_false(_cache.write("<html>busy</html>"))
	assert_false(_cache.write(JSON.stringify({"data": []})))
	assert_eq(_cache.read(), "")
