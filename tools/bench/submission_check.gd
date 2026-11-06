extends RefCounted
## The judging half of `collect_submissions.gd` (docs/specs/benchmark.md §20.4):
## one submission row's files in, one group verdict out (`accepted`, `rejected`,
## or `held`, with its `reason` and `reason_id`). Pure — no files, no network,
## no output — so the unit tests call it directly.
##
## A submission is untrusted data. Each file body is parsed through
## `BenchEntry.from_bytes` and replayed by `BenchVerifier.check`; `reason` is
## `<id>` or `<id> — <detail>`, at most 200 characters, built from ids, numbers,
## and the already-checked file name only — never from a run file's free strings
## (§16.3, §20.4).
##
## A tool, so no `class_name`; `collect_submissions.gd` and the tests preload it.

const Verifier := preload("res://tools/bench/bench_verifier.gd")
const VerifyRecord := preload("res://tools/bench/verify_record.gd")

const STATUS_ACCEPTED: String = "accepted"
const STATUS_REJECTED: String = "rejected"
const STATUS_HELD: String = "held"

const ROW_NEW: String = "new"
const ROW_APPROVED: String = "approved"

const REASON_UNREADABLE: String = "unreadable"
const REASON_FILE_NAME: String = "file_name"
const REASON_BACKEND: String = "backend"
const REASON_GROUP: String = "group"
const REASON_MODEL: String = "model"

const REASON_MAX: int = 200
const RUN_NAME_PATTERN: String = "^[a-z0-9._-]{1,200}\\.json$"


## Judges a submission row `{"id", "status", "files": [{"name", "body"}, ...]}`.
static func judge(row: Dictionary, known_models: Dictionary, config: BenchConfig,
		db: ContentDB, context: Dictionary = {}) -> Dictionary:
	return judge_files(row.get("files"), str(row.get("status", ROW_NEW)), known_models,
		config, db, context)


## Judges `files` (`[{"name", "body"}, ...]`) with row status `row_status`
## (`"new"` or `"approved"`). Returns:
## `{"status": String, "reason": String, "reason_id": String, "files": Array[Dictionary]}`.
static func judge_files(files: Variant, row_status: String, known_models: Dictionary,
		config: BenchConfig, db: ContentDB, context: Dictionary = {}) -> Dictionary:
	if typeof(files) != TYPE_ARRAY:
		return _verdict(STATUS_REJECTED, REASON_UNREADABLE, "files is not an array")
	var raw_list: Array = files
	if raw_list.is_empty() or raw_list.size() > config.submit_max_files:
		return _verdict(STATUS_REJECTED, REASON_UNREADABLE,
			"file count %d is outside 1..%d" % [raw_list.size(), config.submit_max_files])

	var names: Array[String] = []
	var bodies: Array[String] = []
	var bytes_list: Array[PackedByteArray] = []
	var entries: Array[BenchEntry] = []
	var seen_names: Dictionary[String, bool] = {}
	var total_bytes: int = 0

	# 1. unreadable — shape, sizes, and BenchEntry.from_bytes
	for item: Variant in raw_list:
		if typeof(item) != TYPE_DICTIONARY:
			return _verdict(STATUS_REJECTED, REASON_UNREADABLE, "file entry is not an object")
		var d: Dictionary = item
		if typeof(d.get("name")) != TYPE_STRING or typeof(d.get("body")) != TYPE_STRING:
			return _verdict(STATUS_REJECTED, REASON_UNREADABLE,
				"file name and body must be strings")
		var name: String = str(d["name"])
		var body_text: String = str(d["body"])
		var bytes: PackedByteArray = body_text.to_utf8_buffer()
		total_bytes += bytes.size()
		if bytes.size() > config.submit_max_file_bytes \
				or total_bytes > config.submit_max_total_bytes:
			return _verdict(STATUS_REJECTED, REASON_UNREADABLE,
				"submission size exceeds limits")
		var entry: BenchEntry = BenchEntry.from_bytes(bytes)
		if entry == null:
			return _verdict(STATUS_REJECTED, REASON_UNREADABLE, BenchEntry.last_error)
		names.append(name)
		bodies.append(body_text)
		bytes_list.append(bytes)
		entries.append(entry)

	# 2. file_name — pattern, uniqueness, and §10.2's name for its entry
	for i: int in entries.size():
		var name: String = names[i]
		if not _matches(RUN_NAME_PATTERN, name):
			return _verdict(STATUS_REJECTED, REASON_FILE_NAME,
				"the file name does not match the run pattern")
		if seen_names.has(name):
			return _verdict(STATUS_REJECTED, REASON_FILE_NAME,
				"duplicate file name %s" % name)
		seen_names[name] = true
		if name != entries[i].file_name():
			return _verdict(STATUS_REJECTED, REASON_FILE_NAME,
				"%s: the file name is not the entry's own" % name)

	# 3. backend — no bot: models, no bot backend, no mock* backend
	for i: int in entries.size():
		var entry: BenchEntry = entries[i]
		if entry.model.begins_with(BenchEntry.MODEL_BOT_PREFIX) \
				or entry.backend == BenchEntry.BACKEND_BOT \
				or entry.backend.begins_with(BenchGroup.MOCK_PREFIX):
			return _verdict(STATUS_REJECTED, REASON_BACKEND,
				"bot and mock runs cannot be submitted")

	# 4. group — same model, params_id, prompt_version, suite, content_hash, and
	#    exact suite seeds once each
	var first: BenchEntry = entries[0]
	for entry: BenchEntry in entries:
		if entry.model != first.model:
			return _verdict(STATUS_REJECTED, REASON_GROUP, "entries differ in model")
		if entry.params_id != first.params_id:
			return _verdict(STATUS_REJECTED, REASON_GROUP, "entries differ in params_id")
		if entry.prompt_version != first.prompt_version:
			return _verdict(STATUS_REJECTED, REASON_GROUP, "entries differ in prompt_version")
		if entry.suite != first.suite:
			return _verdict(STATUS_REJECTED, REASON_GROUP, "entries differ in suite")
		if entry.content_hash != first.content_hash:
			return _verdict(STATUS_REJECTED, REASON_GROUP, "entries differ in content_hash")
	var wanted_seeds: Array[int] = config.suite_seeds(first.suite)
	if wanted_seeds.is_empty():
		return _verdict(STATUS_REJECTED, REASON_GROUP, "the suite is not one of the benchmark's")
	if entries.size() != wanted_seeds.size():
		return _verdict(STATUS_REJECTED, REASON_GROUP,
			"group has %d files, suite needs %d" % [entries.size(), wanted_seeds.size()])
	var seen_seeds: Dictionary[int, bool] = {}
	for entry: BenchEntry in entries:
		if not wanted_seeds.has(entry.seed_value) or seen_seeds.has(entry.seed_value):
			return _verdict(STATUS_REJECTED, REASON_GROUP,
				"seeds are not the suite's seeds once each")
		seen_seeds[entry.seed_value] = true

	# 5. BenchVerifier.check on each file
	for i: int in entries.size():
		var record: VerifyRecord = Verifier.check(bytes_list[i], names[i], config, db, context)
		if not record.verified:
			return _verdict(STATUS_REJECTED, record.reason,
				"%s: %s" % [names[i], record.detail])

	# 6. held · model — status new and model id not in OpenRouter's list
	if row_status != ROW_APPROVED and not known_models.has(first.model):
		return _verdict(STATUS_HELD, REASON_MODEL,
			"model is not in the public model list")

	# 7. accepted
	var clean_files: Array[Dictionary] = []
	for i: int in names.size():
		clean_files.append({"name": names[i], "body": bodies[i]})
	return {
		"status": STATUS_ACCEPTED,
		"reason": "",
		"reason_id": "",
		"files": clean_files,
	}


static func _verdict(status: String, reason_id: String, detail: String) -> Dictionary:
	var reason: String = reason_id if detail.is_empty() else "%s — %s" % [reason_id, detail]
	return {
		"status": status,
		"reason": reason.left(REASON_MAX),
		"reason_id": reason_id,
		"files": [] as Array[Dictionary],
	}


static func _matches(pattern: String, text: String) -> bool:
	var regex: RegEx = RegEx.create_from_string(pattern)
	return regex.search(text) != null
