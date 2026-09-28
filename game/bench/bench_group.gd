class_name BenchGroup
extends RefCounted
## One of the player's own benchmarks as *Submit* sees it
## (docs/specs/benchmark.md §19.9.3): the recorded runs of one model with one
## set of params, prompt version, suite and content — one row of the board —
## that is complete, current, not a bot's and not a mock's.

## `backend` of a mock run: `mock:…` and `mock-choice:…` (§8.4).
const MOCK_PREFIX: String = "mock"
const DIR_SEPARATOR: String = "__"
## web.md §7.1: where *Submit* gathers a group's files.
const SUBMIT_FOLDER: String = "benchmark/submit/"

var model: String = ""
var params_id: String = ""
## `BenchEffort.of_entry` of the runs.
var effort: String = ""
var score: float = 0.0
var wins: int = 0
var runs: int = 0
## The runs, by seed, and the files they were read from.
var entries: Array[BenchEntry] = []
var paths: Array[String] = []

## Where `copy_files` gathers; the suite points it at a folder of its own.
static var submit_root: String = UserPaths.at(SUBMIT_FOLDER)


## The groups among `library`'s entries read from `own_dir` (the player's
## recorded runs) that may be submitted: complete by `config`'s suites, on
## `content_hash`, neither a bot's nor a mock's. Best score first, then model.
static func own_groups(library: BenchLibrary, own_dir: String, content_hash: String,
		config: BenchConfig) -> Array[BenchGroup]:
	var grouped: Dictionary[String, BenchGroup] = {}
	var order: Array[String] = []
	for i: int in library.entries.size():
		var entry: BenchEntry = library.entries[i]
		if not library.paths[i].begins_with(own_dir) or entry.is_bot() \
				or entry.backend.begins_with(MOCK_PREFIX) or entry.content_hash != content_hash \
				or content_hash.is_empty():
			continue
		# The board's own grouping (§10.3), so a submitted group is one row there.
		var key: String = JSON.stringify([entry.model, entry.params_id, entry.prompt_version,
			entry.parser_version, entry.locale, entry.suite, entry.content_hash])
		if not grouped.has(key):
			var group: BenchGroup = BenchGroup.new()
			group.model = entry.model
			group.params_id = entry.params_id
			group.effort = BenchEffort.of_entry(entry)
			grouped[key] = group
			order.append(key)
		grouped[key].entries.append(entry)
		grouped[key].paths.append(library.paths[i])
	var out: Array[BenchGroup] = []
	for key: String in order:
		var group: BenchGroup = grouped[key]
		if group._score(config, content_hash):
			out.append(group)
	out.sort_custom(func(a: BenchGroup, b: BenchGroup) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return a.model < b.model)
	return out


## `<slug>__<params_id>`, the folder the files are gathered in.
func folder_name() -> String:
	return BenchEntry.slug(model) + DIR_SEPARATOR + params_id


func submit_dir() -> String:
	return submit_root.path_join(folder_name())


## §19.9.3 item 3: the group's files, copied into a clean `submit_dir()` under
## their own names. The copies' paths, or [] when a file could not be copied.
func copy_files() -> Array[String]:
	var dir: String = submit_dir()
	if DirAccess.dir_exists_absolute(dir):
		for file_name: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file_name))
	elif DirAccess.make_dir_recursive_absolute(dir) != OK:
		return []
	var copies: Array[String] = []
	for i: int in entries.size():
		var target: String = dir.path_join(entries[i].file_name())
		if DirAccess.copy_absolute(paths[i], target) != OK:
			return []
		copies.append(target)
	return copies


## The board's figures for the group, its runs put in seed order; false when
## it is not complete.
func _score(config: BenchConfig, content_hash: String) -> bool:
	var order: Array[int] = []
	for i: int in entries.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return entries[a].seed_value < entries[b].seed_value)
	var sorted_entries: Array[BenchEntry] = []
	var sorted_paths: Array[String] = []
	for i: int in order:
		sorted_entries.append(entries[i])
		sorted_paths.append(paths[i])
	entries = sorted_entries
	paths = sorted_paths
	var rows: Array[Dictionary] = BenchScore.rows(entries, config, content_hash)
	if rows.size() != 1 or not bool(rows[0]["complete"]):
		return false
	score = float(rows[0]["score"])
	wins = int(rows[0]["wins"])
	runs = int(rows[0]["runs"])
	return true
