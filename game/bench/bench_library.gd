class_name BenchLibrary
extends RefCounted
## The benchmark entries the game can list and replay (docs/specs/benchmark.md
## §12.1): the shipped showcase, the player's own recorded runs and — in a debug
## build — the repository's working board.
##
## Every file is data: JSON read through `BenchEntry.from_bytes`, never a
## resource. A file that does not read is skipped, counted and warned about once.

const SHOWCASE_DIR: String = "res://benchmark/showcase/"
const DEV_DIR: String = "res://benchmark/runs/"
## web.md §7.1: the folder under `UserPaths.root()`.
const USER_FOLDER: String = "benchmark/runs/"
const MAX_FILES: int = 200
const MAX_BYTES: int = 4_000_000
const EXTENSION: String = "json"

## Where `scan` looks. Tests point them at folders of their own, as they do
## `SaveManager.save_dir`, so the suite never reads or writes the player's runs.
static var showcase_dir: String = SHOWCASE_DIR
static var dev_dir: String = DEV_DIR
static var user_dir: String = UserPaths.at(USER_FOLDER)

var entries: Array[BenchEntry] = []
## Parallel to `entries`: the file each was read from.
var paths: Array[String] = []
## Files that could not be read (too large, not UTF-8, not an entry).
var skipped: int = 0

var _files_seen: int = 0


## The showcase, then the player's runs, then — only with `include_dev` — the
## repository's. A missing folder is empty; at most `MAX_FILES` files in all.
static func scan(include_dev: bool) -> BenchLibrary:
	var library: BenchLibrary = BenchLibrary.new()
	library._read_dir(showcase_dir)
	library._read_dir(user_dir)
	if include_dev:
		library._read_dir(dev_dir)
	return library


func _read_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	var names: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.get_extension() == EXTENSION:
			names.append(file_name)
	names.sort()
	for file_name: String in names:
		if _files_seen >= MAX_FILES:
			return
		_files_seen += 1
		_read_file(dir.path_join(file_name))


func _read_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_skip(path, "cannot be opened")
		return
	if file.get_length() > MAX_BYTES:
		_skip(path, "larger than %d bytes" % MAX_BYTES)
		return
	var entry: BenchEntry = BenchEntry.from_bytes(file.get_buffer(file.get_length()))
	if entry == null:
		_skip(path, BenchEntry.last_error)
		return
	entries.append(entry)
	paths.append(path)


func _skip(path: String, reason: String) -> void:
	skipped += 1
	push_warning("benchmark: %s skipped — %s" % [path, reason])
