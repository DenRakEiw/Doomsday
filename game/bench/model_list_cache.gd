class_name ModelListCache
extends RefCounted
## OpenRouter's public model list as the benchmark modal keeps it
## (docs/specs/benchmark.md §19.8 item 4): the body of the last `GET /models`,
## in `user://benchmark/online/models.json`, reused for
## `player.models_max_age_s`. The body is data, parsed by `ModelCatalogue.parse`;
## a file that does not parse is as good as none.

## web.md §7.1: the folder under `UserPaths.root()` — the online board's.
const FOLDER: String = "benchmark/online/"
const FILE_NAME: String = "models.json"
const TMP_SUFFIX: String = ".tmp"

## Where a new cache lives; the suite points it at a folder of its own
## (`tests/support/pre_run.gd`).
static var default_dir: String = UserPaths.at(FOLDER)

var dir: String = default_dir


func path() -> String:
	return dir.path_join(FILE_NAME)


## The cached body, or "" when there is none.
func read() -> String:
	if not FileAccess.file_exists(path()):
		return ""
	return FileAccess.get_file_as_string(path())


## Whether the cached list is younger than `max_age_s` at `now_unix`.
func is_fresh(max_age_s: int, now_unix: int) -> bool:
	if not FileAccess.file_exists(path()):
		return false
	return now_unix - FileAccess.get_modified_time(path()) < max_age_s


## Keeps `body` when it is the list: written aside first, then moved over.
func write(body: String) -> bool:
	if ModelCatalogue.parse(body).is_empty():
		return false
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var temp: String = path() + TMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(body)
	file.close()
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())
	return DirAccess.rename_absolute(temp, path()) == OK
