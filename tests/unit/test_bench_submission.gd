extends GutTest
## S6.12h — `BenchSubmission` and `BenchSubmitResult` (docs/specs/benchmark.md
## §20.2, §20.3, §20.5, §20.9): the request body for a fixture group (names,
## bodies byte-exact, JSON shape), `group_sha` against a fixed vector computed
## outside Godot, size rules refusing before any transport call, and
## `read_answer` for every status and `submit:*` reason.

const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"
const ROOT: String = "user://test_bench_submission/"
const MODEL: String = "vendor/submit-model"
## Computed outside Godot for the three strings "charlie", "alpha", "bravo".
const VECTOR_GROUP_SHA: String = "3f042dc17bd36fc25abb9e20139d6c803c00f9fb86ecee8039c3fa6529b11cc2"

var _config: BenchConfig = null


func before_each() -> void:
	_config = BenchConfig.load_file()
	Fixtures.remove_root(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)


func after_each() -> void:
	Fixtures.remove_root(ROOT)


func _make_group(count: int = 3) -> BenchGroup:
	var group: BenchGroup = BenchGroup.new()
	group.model = MODEL
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CANARY))
	for i: int in count:
		var seed_value: int = 1001 + i
		var d: Dictionary = base.duplicate(true)
		d["model"] = MODEL
		d["backend"] = BenchJob.BACKEND_OPENROUTER
		d["suite"] = BenchConfig.SUITE_QUICK
		d["seed"] = seed_value
		var text: String = JSON.stringify(d, "\t", false) + "\n"
		var name: String = BenchEntry.file_name_for(MODEL, str(d["params_id"]),
			int(d["prompt_version"]), BenchConfig.SUITE_QUICK, seed_value)
		var path: String = ROOT.path_join(name)
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		group.entries.append(BenchEntry.from_json(text))
		group.paths.append(path)
	return group


func test_group_sha_matches_fixed_external_vector() -> void:
	var hashes: PackedStringArray = PackedStringArray([
		BenchSubmission.sha256_hex("charlie".to_utf8_buffer()),
		BenchSubmission.sha256_hex("alpha".to_utf8_buffer()),
		BenchSubmission.sha256_hex("bravo".to_utf8_buffer()),
	])
	assert_eq(BenchSubmission.group_sha_of(hashes), VECTOR_GROUP_SHA)


func test_from_group_preserves_names_and_bodies_byte_exact() -> void:
	var group: BenchGroup = _make_group(3)
	var sub: BenchSubmission = BenchSubmission.from_group(group, _config)
	assert_not_null(sub, BenchSubmission.last_error)
	assert_eq(sub.files.size(), 3)
	assert_eq(sub.file_sha.size(), 3)
	var parsed: Variant = JSON.parse_string(sub.body())
	assert_typeof(parsed, TYPE_DICTIONARY)
	var p_files: Variant = (parsed as Dictionary).get("p_files")
	assert_typeof(p_files, TYPE_ARRAY)
	var arr: Array = p_files
	assert_eq(arr.size(), 3)
	for i: int in 3:
		var item: Dictionary = arr[i]
		assert_eq(str(item["name"]), group.paths[i].get_file())
		assert_eq(str(item["body"]), FileAccess.get_file_as_string(group.paths[i]))
	assert_eq(sub.group_sha, BenchSubmission.group_sha_of(sub.file_sha))


func test_size_and_count_rules_refuse_before_any_network() -> void:
	var group: BenchGroup = _make_group(3)
	_config.submit_max_files = 2
	assert_null(BenchSubmission.from_group(group, _config))
	assert_false(BenchSubmission.last_error.is_empty())
	_config = BenchConfig.load_file()
	_config.submit_max_file_bytes = 100
	assert_null(BenchSubmission.from_group(group, _config))
	_config = BenchConfig.load_file()
	_config.submit_max_total_bytes = 500
	assert_null(BenchSubmission.from_group(group, _config))


func test_read_answer_maps_every_status_and_reason() -> void:
	var rec: BenchSubmitResult = BenchSubmission.read_answer(200,
		JSON.stringify({"status": "received", "id": 17}).to_utf8_buffer())
	assert_eq(rec.kind, BenchSubmitResult.KIND_RECEIVED)
	assert_eq(rec.id, 17)
	assert_true(rec.is_stored())

	var dup: BenchSubmitResult = BenchSubmission.read_answer(200,
		JSON.stringify({"status": "already", "id": 17}).to_utf8_buffer())
	assert_eq(dup.kind, BenchSubmitResult.KIND_ALREADY)
	assert_eq(dup.id, 17)
	assert_true(dup.is_stored())

	for r: String in ["busy", "full"]:
		var busy: BenchSubmitResult = BenchSubmission.read_answer(400,
			JSON.stringify({"message": "submit:" + r}).to_utf8_buffer())
		assert_eq(busy.kind, BenchSubmitResult.KIND_BUSY, r)
		assert_eq(busy.reason, r)

	var closed: BenchSubmitResult = BenchSubmission.read_answer(400,
		JSON.stringify({"message": "submit:closed"}).to_utf8_buffer())
	assert_eq(closed.kind, BenchSubmitResult.KIND_CLOSED)
	assert_eq(closed.reason, "closed")

	for r: String in ["bad_request", "too_many_files", "bad_name", "too_large", "bad_json", "mixed"]:
		var ref: BenchSubmitResult = BenchSubmission.read_answer(400,
			JSON.stringify({"message": "submit:" + r}).to_utf8_buffer())
		assert_eq(ref.kind, BenchSubmitResult.KIND_REFUSED, r)
		assert_eq(ref.reason, r)

	var http401: BenchSubmitResult = BenchSubmission.read_answer(401,
		JSON.stringify({"message": "Invalid API key"}).to_utf8_buffer())
	assert_eq(http401.kind, BenchSubmitResult.KIND_REFUSED)

	for bad: Array in [
		[0, PackedByteArray()],
		[502, "bad gateway".to_utf8_buffer()],
		[200, "not json".to_utf8_buffer()],
		[200, JSON.stringify({"status": "mystery"}).to_utf8_buffer()],
	]:
		var net: BenchSubmitResult = BenchSubmission.read_answer(int(bad[0]), bad[1])
		assert_eq(net.kind, BenchSubmitResult.KIND_NETWORK, str(bad[0]))
