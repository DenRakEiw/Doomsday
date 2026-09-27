class_name GlobalBoard
extends RefCounted
## The global leaderboard as the game reads it (docs/specs/benchmark.md §16.6):
## the public `leaderboard.json`, parsed and checked. The file comes from the
## network, a cache or the build — it is data from outside, so `parse` never
## crashes and keeps only what it can show safely.

const VERSION: int = 1
const SUITE_STANDARD: String = "standard"
## `validate.py`'s rule for a model name: printable ASCII without spaces.
const MODEL_MAX_LENGTH: int = 200
const PRINTABLE_FIRST: int = 0x21
const PRINTABLE_LAST: int = 0x7E
const SCORE_MAX: float = 100.0
const RUN_FILE_PATTERN: String = "^runs/[a-z0-9._-]+\\.json$"
const SHA256_PATTERN: String = "^[0-9a-f]{64}$"
## `{date}` in the status line: the ISO date at the start of `generated`.
const DATE_LENGTH: int = 10

## The file's ISO time; "" when unusable (or when the file gave none).
var generated: String = ""
var content_hash: String = ""
## Standard-suite rows only, in file order.
var rows: Array[GlobalBoardRow] = []
## Rows or runs refused by the rules below.
var dropped: int = 0
## Non-empty: the file is unusable.
var last_error: String = ""

static var _run_file: RegEx = null
static var _sha256: RegEx = null


## The board in `text`, checked (§16.6): `version` 1, `generated` and
## `content_hash` strings, `rows` a list, at most `config.global_max_rows` rows
## read. A row or a run that breaks a rule is dropped and counted; a row of
## another suite is skipped silently (practice, not an error).
static func parse(text: String, config: BenchConfig) -> GlobalBoard:
	var board: GlobalBoard = GlobalBoard.new()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return board._unusable("not a JSON object")
	var d: Dictionary = json.data
	if not _is_whole(d.get("version")) or int(d["version"]) != VERSION:
		return board._unusable("version: not %d" % VERSION)
	if typeof(d.get("generated")) != TYPE_STRING:
		return board._unusable("generated: missing or not a string")
	if typeof(d.get("content_hash")) != TYPE_STRING:
		return board._unusable("content_hash: missing or not a string")
	if typeof(d.get("rows")) != TYPE_ARRAY:
		return board._unusable("rows: missing or not a list")
	board.generated = str(d["generated"])
	board.content_hash = str(d["content_hash"])
	var list: Array = d["rows"]
	for i: int in mini(list.size(), config.global_max_rows):
		board._read_row(list[i])
	if board.dropped > 0:
		push_warning("global leaderboard: %d rows or runs dropped" % board.dropped)
	return board


## The usable one of the two with the later `generated` (ISO strings compare as
## text; a tie keeps `a`); null when neither is usable.
static func newer(a: GlobalBoard, b: GlobalBoard) -> GlobalBoard:
	var a_usable: bool = a != null and a.is_usable()
	var b_usable: bool = b != null and b.is_usable()
	if a_usable and b_usable:
		return b if b.generated > a.generated else a
	if a_usable:
		return a
	return b if b_usable else null


func is_usable() -> bool:
	return last_error.is_empty()


## The date the status line shows: the first ten characters of `generated`.
func date() -> String:
	return generated.substr(0, DATE_LENGTH)


## Whether `model` is a name the list may show (1–200 printable ASCII
## characters, no space).
static func is_model_name(model: String) -> bool:
	if model.is_empty() or model.length() > MODEL_MAX_LENGTH:
		return false
	for i: int in model.length():
		var code: int = model.unicode_at(i)
		if code < PRINTABLE_FIRST or code > PRINTABLE_LAST:
			return false
	return true


func _unusable(reason: String) -> GlobalBoard:
	last_error = reason
	generated = ""
	rows.clear()
	return self


func _read_row(value: Variant) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		dropped += 1
		return
	var d: Dictionary = value
	if typeof(d.get("suite")) != TYPE_STRING:
		dropped += 1
		return
	if str(d["suite"]) != SUITE_STANDARD:
		return
	if typeof(d.get("model")) != TYPE_STRING or not is_model_name(str(d["model"])):
		dropped += 1
		return
	for key: String in ["runs", "of", "wins"]:
		if not _is_whole(d.get(key)) or int(d[key]) < 0:
			dropped += 1
			return
	if not _is_number(d.get("score")) or float(d["score"]) < 0.0 \
			or float(d["score"]) > SCORE_MAX:
		dropped += 1
		return
	if typeof(d.get("complete")) != TYPE_BOOL or typeof(d.get("content_hash")) != TYPE_STRING:
		dropped += 1
		return
	var row: GlobalBoardRow = GlobalBoardRow.new()
	row.model = str(d["model"])
	row.params_id = str(d["params_id"]) if typeof(d.get("params_id")) == TYPE_STRING else ""
	row.content_hash = str(d["content_hash"])
	row.complete = bool(d["complete"])
	row.runs = int(d["runs"])
	row.of = int(d["of"])
	row.wins = int(d["wins"])
	row.score = float(d["score"])
	# §18: optional; anything but a level, a marked raw value (`reasoning-low`) or
	# a short lower-case word is shown as the dash, never dropped — the row itself
	# is sound.
	if typeof(d.get(BenchEffort.PARAM)) == TYPE_STRING \
			and BenchEffort.label_is_safe(str(d[BenchEffort.PARAM])):
		row.effort = str(d[BenchEffort.PARAM])
	if typeof(d.get("seeds")) == TYPE_ARRAY:
		for seed_value: Variant in d["seeds"]:
			var run: GlobalBoardRun = _read_run(seed_value)
			if run == null:
				dropped += 1
			else:
				row.seeds.append(run)
	elif d.has("seeds"):
		dropped += 1
	rows.append(row)


static func _read_run(value: Variant) -> GlobalBoardRun:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = value
	if not _is_whole(d.get("seed")) or not _is_whole(d.get("days")):
		return null
	if typeof(d.get("file")) != TYPE_STRING or typeof(d.get("sha256")) != TYPE_STRING \
			or typeof(d.get("outcome")) != TYPE_STRING or not _is_number(d.get("score")):
		return null
	var file: String = str(d["file"])
	var sha256: String = str(d["sha256"])
	if _regex_run_file().search(file) == null or _regex_sha256().search(sha256) == null:
		return null
	var run: GlobalBoardRun = GlobalBoardRun.new()
	run.seed_value = int(d["seed"])
	run.file = file
	run.sha256 = sha256
	run.outcome = str(d["outcome"])
	run.days = int(d["days"])
	run.score = float(d["score"])
	return run


static func _regex_run_file() -> RegEx:
	if _run_file == null:
		_run_file = RegEx.create_from_string(RUN_FILE_PATTERN)
	return _run_file


static func _regex_sha256() -> RegEx:
	if _sha256 == null:
		_sha256 = RegEx.create_from_string(SHA256_PATTERN)
	return _sha256


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


static func _is_whole(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_INT:
		return true
	return type == TYPE_FLOAT and float(value) == floorf(float(value))
