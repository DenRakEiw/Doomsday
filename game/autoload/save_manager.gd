extends Node
## Saves and loads runs (spec ui-foundation.md §10.4). `WorldSerializer` owns the
## format; this owns the file, and it is the only thing in the project that
## writes one.
##
## A save is written to a temporary file and renamed over the old one, so a crash
## half-way through loses the new save rather than the old one. Nothing here ever
## loads a `.tres`: saves are versioned JSON (CLAUDE.md).
##
## An autoload, so no `class_name`. Beware when editing: inside this script an
## unqualified `load(…)` is GDScript's global resource loader, never the method
## below — call it as `self.load(…)` or not at all.

const SAVE_DIR: String = "user://saves/"
const SUFFIX: String = ".json"
const TMP_SUFFIX: String = ".tmp"

## Reasons this class produces; the rest come from `WorldSerializer.REASON_*`.
const REASON_NO_RUN: String = "save_no_run"
const REASON_NO_CONTENT: String = "save_no_content"
const REASON_WRITE_FAILED: String = "save_write_failed"
const REASON_NOT_FOUND: String = "save_not_found"
const REASON_READ_FAILED: String = "save_read_failed"


## Writes the running simulation to `slot`. "" means it worked, anything else is
## the reason it did not.
func save(slot: String) -> String:
	if Game.sim == null:
		return REASON_NO_RUN
	if not _ensure_dir():
		return REASON_WRITE_FAILED
	var final_path: String = path_for(slot)
	var tmp_path: String = final_path + TMP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return REASON_WRITE_FAILED
	file.store_string(WorldSerializer.to_json(Game.sim))
	file.close()
	# Windows will not rename onto an existing file, so the old save goes first.
	# The new one is already on disk complete at this point.
	if FileAccess.file_exists(final_path) \
			and DirAccess.remove_absolute(final_path) != OK:
		return REASON_WRITE_FAILED
	if DirAccess.rename_absolute(tmp_path, final_path) != OK:
		return REASON_WRITE_FAILED
	return ""


## Loads `slot` and, when it works, hands the run to `Game`. "" means it worked.
func load(slot: String) -> String:
	var path: String = path_for(slot)
	if not FileAccess.file_exists(path):
		return REASON_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return REASON_READ_FAILED
	var db: ContentDB = Game.db
	if db == null:
		# Nothing has loaded content yet: a save cannot be checked against
		# content that is not there, and guessing would be worse.
		return REASON_NO_CONTENT
	var result: LoadResult = WorldSerializer.from_json(file.get_as_text(), db)
	if not result.ok():
		return result.reason
	if result.content_mismatch:
		# Playable, but a replay of its command log would not reproduce it.
		push_warning("save %s was written on different content" % slot)
	Game.adopt_loaded(result.sim)
	return ""


## The slots on disk, in alphabetical order.
func list_slots() -> Array[String]:
	var slots: Array[String] = []
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return slots
	var names: PackedStringArray = DirAccess.get_files_at(SAVE_DIR)
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(SUFFIX):
			slots.append(file_name.trim_suffix(SUFFIX))
	return slots


func delete(slot: String) -> String:
	var path: String = path_for(slot)
	if not FileAccess.file_exists(path):
		return REASON_NOT_FOUND
	if DirAccess.remove_absolute(path) != OK:
		return REASON_WRITE_FAILED
	return ""


func path_for(slot: String) -> String:
	return SAVE_DIR.path_join(slot + SUFFIX)


func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		return true
	return DirAccess.make_dir_recursive_absolute(SAVE_DIR) == OK
