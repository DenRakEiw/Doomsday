class_name BenchSubmitLog
extends RefCounted
## The local note of groups the player has sent (`user://benchmark/submitted.json`,
## docs/specs/benchmark.md §20.5, §20.7): which group hash was sent on which UTC
## date, so the Benchmark list can show *Sent*, *On the leaderboard* or *Sent …,
## still not on the leaderboard*.
##
## A missing or unreadable file is an empty log (never a crash) and is rewritten
## on the next send. Nothing outside the player's own list trusts this file.

const FOLDER: String = "benchmark/"
const FILE_NAME: String = "submitted.json"
const TEMP_SUFFIX: String = ".tmp"
const VERSION: int = 1
const FIELD_VERSION: String = "version"
const FIELD_SENT: String = "sent"
const FIELD_GROUP_SHA: String = "group_sha"
const FIELD_FILES: String = "files"
const FIELD_DATE: String = "date"
const FIELD_ID: String = "id"
const SECONDS_PER_DAY: int = 86400
const DATE_PATTERN: String = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

## §20.7's four states for a group line in the Benchmark list.
const STATE_SUBMIT: String = "submit"
const STATE_SENT: String = "sent"
const STATE_LISTED: String = "listed"
const STATE_NOT_LISTED: String = "not_listed"

## Redirected by `pre_run.gd` so tests never touch the player's file.
static var default_dir: String = UserPaths.at(FOLDER)

var dir: String = default_dir
var sent: Array[Dictionary] = []

static var _date_regex: RegEx = null


func file_path() -> String:
	return dir.path_join(FILE_NAME)


## Reads the log from `p_dir`; a missing or broken file returns an empty log.
static func load_log(p_dir: String = default_dir) -> BenchSubmitLog:
	var log_store: BenchSubmitLog = BenchSubmitLog.new()
	log_store.dir = p_dir
	log_store.reload()
	return log_store


func reload() -> void:
	sent.clear()
	var path: String = file_path()
	if not FileAccess.file_exists(path):
		return
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK \
			or typeof(json.data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = json.data
	if int(d.get(FIELD_VERSION, 0)) != VERSION or typeof(d.get(FIELD_SENT)) != TYPE_ARRAY:
		return
	for item: Variant in d[FIELD_SENT]:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		if typeof(row.get(FIELD_GROUP_SHA)) != TYPE_STRING \
				or typeof(row.get(FIELD_DATE)) != TYPE_STRING \
				or typeof(row.get(FIELD_FILES)) != TYPE_ARRAY:
			continue
		var files: Array[String] = []
		for f: Variant in row[FIELD_FILES]:
			if typeof(f) == TYPE_STRING:
				files.append(str(f))
		sent.append({
			FIELD_GROUP_SHA: str(row[FIELD_GROUP_SHA]),
			FIELD_FILES: files,
			FIELD_DATE: str(row[FIELD_DATE]),
			FIELD_ID: int(row.get(FIELD_ID, 0)),
		})


## Records `submission` as sent on `date` (`YYYY-MM-DD`) and writes the file.
func record(submission: BenchSubmission, id: int,
		date: String = Time.get_date_string_from_system(true)) -> bool:
	reload()
	var files: Array[String] = []
	for h: String in submission.file_sha:
		files.append(h)
	var updated: bool = false
	for i: int in sent.size():
		if str(sent[i][FIELD_GROUP_SHA]) == submission.group_sha:
			sent[i] = {
				FIELD_GROUP_SHA: submission.group_sha,
				FIELD_FILES: files,
				FIELD_DATE: date,
				FIELD_ID: id,
			}
			updated = true
			break
	if not updated:
		sent.append({
			FIELD_GROUP_SHA: submission.group_sha,
			FIELD_FILES: files,
			FIELD_DATE: date,
			FIELD_ID: id,
		})
	return _write()


func entry_for(group_sha: String) -> Dictionary:
	for row: Dictionary in sent:
		if str(row[FIELD_GROUP_SHA]) == group_sha:
			return row
	return {}


## §20.7: decides what a complete own group's row shows from its current file
## hashes, this log and the known `board` (null when none is known).
## Returns `{"state": STATE_*, "date": String}`.
func group_status(group: BenchGroup, board: GlobalBoard, config: BenchConfig) -> Dictionary:
	var hashes: PackedStringArray = file_hashes_of(group)
	if hashes.is_empty():
		return {"state": STATE_SUBMIT, "date": ""}
	if is_listed_on_board(hashes, board):
		return {"state": STATE_LISTED, "date": ""}
	var group_sha: String = BenchSubmission.group_sha_of(hashes)
	var logged: Dictionary = entry_for(group_sha)
	if logged.is_empty():
		return {"state": STATE_SUBMIT, "date": ""}
	var sent_date: String = str(logged[FIELD_DATE])
	if board != null and _days_between(sent_date, board.date()) >= config.submit_not_listed_days:
		return {"state": STATE_NOT_LISTED, "date": sent_date}
	return {"state": STATE_SENT, "date": sent_date}


## The current SHA-256 of each of `group`'s files; empty when any file is missing.
static func file_hashes_of(group: BenchGroup) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if group == null or group.paths.is_empty():
		return out
	for path: String in group.paths:
		if not FileAccess.file_exists(path):
			return PackedStringArray()
		out.append(BenchSubmission.sha256_hex(FileAccess.get_file_as_bytes(path)))
	return out


## §20.7: true when every file hash of the group is a `seeds[].sha256` of some
## row on `board`.
static func is_listed_on_board(file_hashes: PackedStringArray, board: GlobalBoard) -> bool:
	if board == null or file_hashes.is_empty():
		return false
	for row: GlobalBoardRow in board.rows:
		var row_hashes: Dictionary[String, bool] = {}
		for run: GlobalBoardRun in row.seeds:
			row_hashes[run.sha256] = true
		var all_in_row: bool = true
		for h: String in file_hashes:
			if not row_hashes.has(h):
				all_in_row = false
				break
		if all_in_row:
			return true
	return false


static func _days_between(from_date: String, to_date: String) -> int:
	if _date_regex == null:
		_date_regex = RegEx.create_from_string(DATE_PATTERN)
	if _date_regex.search(from_date) == null or _date_regex.search(to_date) == null:
		return -1
	var from_s: int = Time.get_unix_time_from_datetime_string(from_date + "T00:00:00Z")
	var to_s: int = Time.get_unix_time_from_datetime_string(to_date + "T00:00:00Z")
	return int(floor(float(to_s - from_s) / float(SECONDS_PER_DAY)))


func _write() -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var path: String = file_path()
	var temp: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	var text: String = JSON.stringify({
		FIELD_VERSION: VERSION,
		FIELD_SENT: sent,
	}, "\t") + "\n"
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK
