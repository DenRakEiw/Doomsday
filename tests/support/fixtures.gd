class_name Fixtures
extends RefCounted
## Shared set-up for the test suite.
##
## Tests build their own world from here and share no mutable state. A test may
## write simulation state directly to arrange a situation; nothing outside
## `tests/` may.
##
## The simulation helpers of `docs/specs/core.md` §9 — `sim`, `sim_with_origin`,
## `grant`, `buy` — arrive with `Simulation` in S1.2.

## A content root of the same shape as `res://data`, described in
## `docs/specs/core.md` §9. Frozen, its own `balance.json` included, so that
## retuning the game never breaks a unit test.
const WORLD_SMALL: String = "res://tests/fixtures/world_small"

## Where `write_root` puts the roots a test builds. Outside the project, so a
## crashed test never leaves anything in the repository.
const TEMP_ROOT: String = "user://test_content"

const REGION_COUNT: int = 6
const LINK_COUNT: int = 7
const TECH_NODE_COUNT: int = 9

## Loaded once: the database is immutable, so every test may share it.
static var _db: ContentDB = null


## The fixture world, loaded and asserted to be clean.
static func db() -> ContentDB:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_SMALL)
		assert(result.ok(), "the fixture content must load cleanly:\n%s" % result.error_text())
		_db = result.db
	return _db


## The fixture's files, parsed but not validated, as a fresh mutable copy per
## call: `{"balance": …, "regions": …, "links": …, "tech": [ … ]}`. A test breaks
## one field of this and loads the rest through `ContentLoader.load_from_dicts`.
static func raw_content() -> Dictionary:
	return {
		"balance": read_json(WORLD_SMALL.path_join("balance.json")),
		"regions": read_json(WORLD_SMALL.path_join("world/regions.json")),
		"links": read_json(WORLD_SMALL.path_join("world/links.json")),
		"tech": [read_json(WORLD_SMALL.path_join("tech/fixture.json"))],
	}


## Loads `raw_content` and hands the parts to `ContentLoader` in its own order.
static func load_raw(content: Dictionary) -> ContentLoadResult:
	var tech: Array[Dictionary] = []
	for entry: Variant in content["tech"]:
		tech.append(entry)
	return ContentLoader.load_from_dicts(content["balance"], content["regions"], content["links"],
		tech)


## The four files of a content root as text, so that a test can write a root that
## `ContentLoader.load_root` then reads from disk. `indent` is what makes two
## roots differ in whitespace and in nothing else.
static func root_files(content: Dictionary, indent: String = "\t") -> Dictionary[String, String]:
	var tech: Array = content["tech"]
	# Full precision, like the save writer: the default float formatting is lossy
	# and a rewritten root would then no longer hash like the one it came from.
	return {
		"balance.json": JSON.stringify(content["balance"], indent, true, true),
		"world/regions.json": JSON.stringify(content["regions"], indent, true, true),
		"world/links.json": JSON.stringify(content["links"], indent, true, true),
		"tech/fixture.json": JSON.stringify(tech[0], indent, true, true),
	}


## Writes a content root below `user://` and returns its path. `files` maps a
## path inside the root to its text, so a test can write a file that is not JSON
## at all. Any earlier root of the same name is removed first.
static func write_root(name: String, files: Dictionary[String, String]) -> String:
	var root: String = TEMP_ROOT.path_join(name)
	remove_root(root)
	for relative: String in files:
		var path: String = root.path_join(relative)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		assert(file != null, "cannot write %s" % path)
		file.store_string(files[relative])
	return root


## Removes a directory and everything below it. A missing directory is fine.
static func remove_root(root: String) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = root.path_join(entry)
		if dir.current_is_dir():
			remove_root(path)
		else:
			DirAccess.remove_absolute(path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(root)


## One parsed JSON object, deep-copied so that a caller may edit it freely.
static func read_json(path: String) -> Dictionary:
	var json: JSON = JSON.new()
	assert(json.parse(FileAccess.get_file_as_string(path)) == OK, "cannot parse %s" % path)
	var parsed: Dictionary = json.data
	return parsed.duplicate(true)
