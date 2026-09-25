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
## What `peek_day` answers for a slot it cannot read a day out of.
const NO_DAY: int = -1
## The slot the run writes itself into (m3-screens §7.5).
const AUTOSAVE: String = "autosave"
const REASON_READ_FAILED: String = "save_read_failed"

## Where the slots live. release.md §8: the smoke run points it at a folder of
## its own, so a bot run never writes over the player's autosave.
var save_dir: String = SAVE_DIR


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
	if not DirAccess.dir_exists_absolute(save_dir):
		return slots
	var names: PackedStringArray = DirAccess.get_files_at(save_dir)
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


## The day a slot stands at, without loading the run (m3-screens §7.1). −1 for a
## missing, unreadable or broken file: the title shows no caption then.
func peek_day(slot: String) -> int:
	var path: String = path_for(slot)
	if not FileAccess.file_exists(path):
		return NO_DAY
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return NO_DAY
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return NO_DAY
	var save: Dictionary = json.data
	if typeof(save.get("world")) != TYPE_DICTIONARY:
		return NO_DAY
	var world: Dictionary = save["world"]
	var day: Variant = world.get("day")
	if typeof(day) != TYPE_FLOAT and typeof(day) != TYPE_INT:
		return NO_DAY
	return int(day)


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


func path_for(slot: String) -> String:
	return save_dir.path_join(slot + SUFFIX)


func _ensure_dir() -> bool:
	if DirAccess.dir_exists_absolute(save_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(save_dir) == OK
