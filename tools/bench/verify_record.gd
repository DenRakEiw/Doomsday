extends RefCounted
## One run's verification record, `verified/<run file name>` in the public
## leaderboard repository (docs/specs/benchmark.md §16.3): did the run's commands,
## replayed on this game checkout, reach what the run claims? Written by the
## verifier only; the leaderboard writer counts a run only while its record is
## current (the same SHA-256) and `verified`.
##
## A tool, so no `class_name`; the verifier and the tests preload it.

const VERSION: int = 1
## `days` and `end_day` when no replay happened.
const NO_DAYS: int = -1
## `score` is written to one decimal, like an entry's (§10.1).
const SCORE_STEP: float = 0.1
## `detail` never grows past this (§16.3).
const DETAIL_MAX: int = 200

## Every key, in the order the file lists them (§16.3).
const KEYS: Array[String] = ["version", "file", "sha256", "verified", "reason", "detail",
	"game_commit", "game_version", "content_hash", "state_hash", "outcome", "days", "end_day",
	"score", "checked"]
const STRING_KEYS: Array[String] = ["file", "sha256", "reason", "detail", "game_commit",
	"game_version", "content_hash", "state_hash", "outcome", "checked"]
const WHOLE_KEYS: Array[String] = ["version", "days", "end_day"]

var version: int = VERSION
## `runs/<name>.json` — the run's already-checked file name.
var file: String = ""
## Hex SHA-256 of the run file's bytes as they were checked.
var sha256: String = ""
var verified: bool = false
## "" when verified, else one of the verifier's reason ids (§16.4).
var reason: String = ""
## A short English line made of ids and numbers only — never a run file's free strings.
var detail: String = ""
var game_commit: String = ""
var game_version: String = ""
var content_hash: String = ""
var state_hash: String = ""
var outcome: String = ""
var days: int = NO_DAYS
var end_day: int = NO_DAYS
var score: float = 0.0
## The UTC date the run was checked, `YYYY-MM-DD`.
var checked: String = ""


## The run file's name, from `file`.
func run_name() -> String:
	return file.get_file()


## Exactly §16.3's keys, in its order.
func to_dict() -> Dictionary:
	return {
		"version": version,
		"file": file,
		"sha256": sha256,
		"verified": verified,
		"reason": reason,
		"detail": detail.left(DETAIL_MAX),
		"game_commit": game_commit,
		"game_version": game_version,
		"content_hash": content_hash,
		"state_hash": state_hash,
		"outcome": outcome,
		"days": days,
		"end_day": end_day,
		"score": snappedf(score, SCORE_STEP),
		"checked": checked,
	}


## The file's text: tab-indented, the keys in `to_dict`'s order.
func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", false) + "\n"


## Null — never a crash — for a missing or ill-typed key, another version, or a
## verdict that contradicts its reason. A record that does not read counts as
## missing: its run is verified again.
static func from_dict(d: Dictionary) -> RefCounted:
	for key: String in STRING_KEYS:
		if typeof(d.get(key)) != TYPE_STRING:
			return null
	for key: String in WHOLE_KEYS:
		if not _is_whole(d.get(key)):
			return null
	if typeof(d.get("verified")) != TYPE_BOOL:
		return null
	var score_type: int = typeof(d.get("score"))
	if score_type != TYPE_FLOAT and score_type != TYPE_INT:
		return null
	if int(d["version"]) != VERSION:
		return null
	if bool(d["verified"]) != str(d["reason"]).is_empty():
		return null
	var record: RefCounted = new()
	record.version = int(d["version"])
	record.file = str(d["file"])
	record.sha256 = str(d["sha256"])
	record.verified = bool(d["verified"])
	record.reason = str(d["reason"])
	record.detail = str(d["detail"])
	record.game_commit = str(d["game_commit"])
	record.game_version = str(d["game_version"])
	record.content_hash = str(d["content_hash"])
	record.state_hash = str(d["state_hash"])
	record.outcome = str(d["outcome"])
	record.days = int(d["days"])
	record.end_day = int(d["end_day"])
	record.score = float(d["score"])
	record.checked = str(d["checked"])
	return record


## A record file's text read; null when it is not a JSON object or not a record.
static func from_json(text: String) -> RefCounted:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return from_dict(json.data)


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
