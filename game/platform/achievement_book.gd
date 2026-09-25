class_name AchievementBook
extends RefCounted
## The achievements (release.md §2.1, §3): loads and validates
## `data/achievements.json` and evaluates its closed grammar against a profile
## dict and a finished run's facts. Pure — no autoload, no content: the ids of
## architectures, scenarios, difficulties, flags and Codex tabs are checked
## against the content by a test, not here.
##
## A bad file loads empty with reasons in `errors`, never crashes.

const PATH: String = "res://data/achievements.json"
const VERSION: int = 1
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"
const WIN_PREFIX: String = "win_"

const KEY_VERSION: String = "version"
const KEY_STATS: String = "stats"
const KEY_ACHIEVEMENTS: String = "achievements"
const KEY_ID: String = "id"
const KEY_HIDDEN: String = "hidden"
const KEY_WHEN: String = "when"

## §3.2, profile keys — checked against the profile after a run and at start.
const WHEN_RUNS_COMPLETED: String = "runs_completed"
const WHEN_RUNS_WON: String = "runs_won"
const WHEN_OUTCOMES_WON: String = "outcomes_won"
const WHEN_ARCHITECTURES_WON: String = "architectures_won"
const WHEN_ENDINGS_SEEN: String = "endings_seen"
const WHEN_CODEX_ALL: String = "codex_all"
## §3.2, run keys — only at a run's end.
const WHEN_WON: String = "won"
const WHEN_OUTCOME: String = "outcome"
const WHEN_VARIANT: String = "variant"
const WHEN_ARCHITECTURE: String = "architecture"
const WHEN_DIFFICULTY: String = "difficulty"
const WHEN_SCENARIO: String = "scenario"
const WHEN_DIRECTIVES_MIN: String = "directives_min"
const WHEN_DAYS_MAX: String = "days_max"
const WHEN_FLAG: String = "flag"

## Keys whose value is a whole number ≥ 1.
const INT_KEYS: Array[String] = [WHEN_RUNS_COMPLETED, WHEN_RUNS_WON, WHEN_ENDINGS_SEEN,
	WHEN_DIRECTIVES_MIN, WHEN_DAYS_MAX]
## Keys whose value is a non-empty list of ids.
const LIST_KEYS: Array[String] = [WHEN_OUTCOMES_WON, WHEN_ARCHITECTURES_WON, WHEN_CODEX_ALL,
	WHEN_OUTCOME, WHEN_VARIANT, WHEN_ARCHITECTURE, WHEN_DIFFICULTY, WHEN_SCENARIO, WHEN_FLAG]
const RUN_KEYS: Array[String] = [WHEN_WON, WHEN_OUTCOME, WHEN_VARIANT, WHEN_ARCHITECTURE,
	WHEN_DIFFICULTY, WHEN_SCENARIO, WHEN_DIRECTIVES_MIN, WHEN_DAYS_MAX, WHEN_FLAG]
## The list keys that name an outcome.
const OUTCOME_KEYS: Array[String] = [WHEN_OUTCOMES_WON, WHEN_OUTCOME]
## §3.3: the placeholder a detail string takes from each numeric key.
const DETAIL_COUNT: String = "count"
const DETAIL_DAYS: String = "days"
const DETAIL_BY_KEY: Dictionary[String, String] = {
	WHEN_RUNS_COMPLETED: DETAIL_COUNT,
	WHEN_RUNS_WON: DETAIL_COUNT,
	WHEN_ENDINGS_SEEN: DETAIL_COUNT,
	WHEN_DIRECTIVES_MIN: DETAIL_COUNT,
	WHEN_DAYS_MAX: DETAIL_DAYS,
}
## §2.1: the profile counters a platform mirrors as stats.
const STAT_NAMES: Array[String] = [WHEN_RUNS_COMPLETED, WHEN_RUNS_WON]

## The profile dict's fields (`ProfileManager.to_dict()`; a test keeps them equal).
const PROFILE_RUNS: String = "runs_completed"
const PROFILE_WON: String = "runs_won"
const PROFILE_WINS_BY_OUTCOME: String = "wins_by_outcome"
const PROFILE_BY_ARCHITECTURE: String = "by_architecture"
const PROFILE_ARCH_WINS: String = "wins"
const PROFILE_ENDINGS_SEEN: String = "endings_seen"
const PROFILE_CODEX: String = "codex"
const PROFILE_ACHIEVEMENTS: String = "achievements"

## A finished run's facts (§2.3).
const FACT_OUTCOME: String = "outcome"
const FACT_VARIANT: String = "variant"
const FACT_ARCHITECTURE: String = "architecture"
const FACT_DIFFICULTY: String = "difficulty"
const FACT_SCENARIO: String = "scenario"
const FACT_DIRECTIVES: String = "directives"
const FACT_DAYS: String = "days"
const FACT_WON: String = "won"
const FACT_FLAGS: String = "flags"

## §3.2: a list key has a progress row only from this many ids on.
const MIN_PROGRESS_LIST: int = 2
## What `progress` answers for a def without a progress row.
const NO_PROGRESS: Array[int] = [-1, -1]

static var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)

var defs: Array[AchievementDef] = []
var stats: Array[String] = []
## Why the file loaded empty; nothing when it loaded.
var errors: Array[String] = []


static func load_file(path: String = PATH) -> AchievementBook:
	var book: AchievementBook = AchievementBook.new()
	if not FileAccess.file_exists(path):
		book.errors.append("%s: missing" % path)
		return book
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		book.errors.append("%s: line %d: %s" % [path, json.get_error_line(),
			json.get_error_message()])
		return book
	book.read(json.data, path)
	return book


## Reads an already-parsed file; on any error the book stays empty.
func read(raw: Variant, source: String = PATH) -> void:
	defs.clear()
	stats.clear()
	errors.clear()
	var parsed_defs: Array[AchievementDef] = []
	var parsed_stats: Array[String] = []
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: the root is not an object" % source)
		return
	var root: Dictionary = raw
	_check_keys(root, [KEY_VERSION, KEY_STATS, KEY_ACHIEVEMENTS], source)
	if not _is_whole(root.get(KEY_VERSION)) or int(root[KEY_VERSION]) != VERSION:
		errors.append("%s: version must be %d" % [source, VERSION])
	if typeof(root.get(KEY_STATS)) != TYPE_ARRAY:
		errors.append("%s: stats must be a list" % source)
	else:
		for stat: Variant in root[KEY_STATS]:
			if typeof(stat) != TYPE_STRING or not STAT_NAMES.has(str(stat)):
				errors.append("%s: unknown stat %s" % [source, str(stat)])
			elif not parsed_stats.has(str(stat)):
				parsed_stats.append(str(stat))
	if typeof(root.get(KEY_ACHIEVEMENTS)) != TYPE_ARRAY:
		errors.append("%s: achievements must be a list" % source)
	else:
		var seen: Array[String] = []
		for entry: Variant in root[KEY_ACHIEVEMENTS]:
			var def: AchievementDef = _read_def(entry, source)
			if def == null:
				continue
			if seen.has(def.id):
				errors.append("%s: duplicate id %s" % [source, def.id])
				continue
			seen.append(def.id)
			parsed_defs.append(def)
	if errors.is_empty():
		defs = parsed_defs
		stats = parsed_stats


func find(id: String) -> AchievementDef:
	for def: AchievementDef in defs:
		if def.id == id:
			return def
	return null


## Every flag any def's `flag` list names, each once — the facts a run end
## collects (§2.3).
func flag_ids() -> Array[String]:
	var out: Array[String] = []
	for def: AchievementDef in defs:
		for flag: Variant in def.when.get(WHEN_FLAG, []):
			if not out.has(str(flag)):
				out.append(str(flag))
	return out


## The ids whose `when` holds and that `profile["achievements"]` lacks, in file order.
## `profile` is `ProfileManager.to_dict()` after the run was counted; `run` is the run's facts
## (§2.3) or {} — then every def with a run key is skipped. `totals` maps a Codex tab to the
## content's full id list; a def with `codex_all` is skipped when a tab it names is missing.
func newly_earned(profile: Dictionary, run: Dictionary,
		totals: Dictionary[String, Array]) -> Array[String]:
	var earned: Array = _list(profile, PROFILE_ACHIEVEMENTS)
	var out: Array[String] = []
	for def: AchievementDef in defs:
		if earned.has(def.id):
			continue
		if run.is_empty() and _has_run_key(def):
			continue
		if def.when.has(WHEN_CODEX_ALL) and not _totals_cover(def, totals):
			continue
		if _holds(def, profile, run, totals):
			out.append(def.id)
	return out


## [count, needed] for a def with exactly one countable key (§3.2), else [-1, -1].
func progress(def: AchievementDef, profile: Dictionary,
		totals: Dictionary[String, Array]) -> Array[int]:
	if def == null or def.when.size() != 1:
		return NO_PROGRESS.duplicate()
	var key: String = str(def.when.keys()[0])
	var value: Variant = def.when[key]
	match key:
		WHEN_RUNS_COMPLETED:
			return [_whole(profile, PROFILE_RUNS), int(value)]
		WHEN_RUNS_WON:
			return [_whole(profile, PROFILE_WON), int(value)]
		WHEN_ENDINGS_SEEN:
			return [_list(profile, PROFILE_ENDINGS_SEEN).size(), int(value)]
		WHEN_OUTCOMES_WON, WHEN_ARCHITECTURES_WON:
			var ids: Array = value
			if ids.size() < MIN_PROGRESS_LIST:
				return NO_PROGRESS.duplicate()
			var count: int = 0
			for id: Variant in ids:
				if _won_one(key, str(id), profile):
					count += 1
			return [count, ids.size()]
		WHEN_CODEX_ALL:
			var tabs: Array = value
			if tabs.size() != 1 or not totals.has(str(tabs[0])):
				return NO_PROGRESS.duplicate()
			var tab: String = str(tabs[0])
			var seen: Array = _codex_tab(profile, tab)
			var count: int = 0
			for id: Variant in totals[tab]:
				if seen.has(id):
					count += 1
			return [count, totals[tab].size()]
	return NO_PROGRESS.duplicate()


## The {count}/{days} value a detail string is formatted with (§3.3); {} when none.
func detail_values(def: AchievementDef) -> Dictionary:
	if def == null:
		return {}
	for key: String in DETAIL_BY_KEY:
		if def.when.has(key):
			return {DETAIL_BY_KEY[key]: int(def.when[key])}
	return {}


# ------------------------------------------------------------------ reading


func _read_def(entry: Variant, source: String) -> AchievementDef:
	if typeof(entry) != TYPE_DICTIONARY:
		errors.append("%s: an achievement is not an object" % source)
		return null
	var d: Dictionary = entry
	var id: String = str(d.get(KEY_ID, "")) if typeof(d.get(KEY_ID)) == TYPE_STRING else ""
	var where: String = "%s: %s" % [source, id if not id.is_empty() else "?"]
	if _id_regex.search(id) == null:
		errors.append("%s: the id is not snake_case" % where)
		return null
	var before: int = errors.size()
	_check_keys(d, [KEY_ID, KEY_HIDDEN, KEY_WHEN], where)
	if d.has(KEY_HIDDEN) and typeof(d[KEY_HIDDEN]) != TYPE_BOOL:
		errors.append("%s: hidden must be true or false" % where)
	if typeof(d.get(KEY_WHEN)) != TYPE_DICTIONARY or (d[KEY_WHEN] as Dictionary).is_empty():
		errors.append("%s: when must be a non-empty object" % where)
		return null
	var when: Dictionary = {}
	var raw_when: Dictionary = d[KEY_WHEN]
	for key: Variant in raw_when:
		var name: String = str(key)
		if name.begins_with("_"):
			continue
		var value: Variant = _read_condition(name, raw_when[key], where)
		if value != null:
			when[name] = value
	if when.is_empty() and errors.size() == before:
		errors.append("%s: when has no condition" % where)
	if errors.size() != before:
		return null
	var def: AchievementDef = AchievementDef.new()
	def.id = id
	def.hidden = bool(d.get(KEY_HIDDEN, false))
	def.when = when
	return def


## The condition's value in its typed form, or null (with a reason) when wrong.
func _read_condition(key: String, value: Variant, where: String) -> Variant:
	if key == WHEN_WON:
		if typeof(value) != TYPE_BOOL or not bool(value):
			errors.append("%s: won must be true" % where)
			return null
		return true
	if INT_KEYS.has(key):
		if not _is_whole(value) or int(value) < 1:
			errors.append("%s: %s must be a whole number of at least 1" % [where, key])
			return null
		return int(value)
	if LIST_KEYS.has(key):
		if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
			errors.append("%s: %s must be a non-empty list" % [where, key])
			return null
		var ids: Array[String] = []
		for id: Variant in value:
			if typeof(id) != TYPE_STRING or _id_regex.search(str(id)) == null:
				errors.append("%s: %s names %s, not an id" % [where, key, str(id)])
				return null
			if OUTCOME_KEYS.has(key) and not _is_outcome(key, str(id)):
				errors.append("%s: %s names %s, not an outcome it can hold" % [where, key,
					str(id)])
				return null
			if not ids.has(str(id)):
				ids.append(str(id))
		return ids
	errors.append("%s: unknown condition %s" % [where, key])
	return null


func _check_keys(d: Dictionary, allowed: Array[String], where: String) -> void:
	for key: Variant in d:
		var name: String = str(key)
		if not name.begins_with("_") and not allowed.has(name):
			errors.append("%s: unknown key %s" % [where, name])


## `outcomes_won` names wins only; neither names `none`.
static func _is_outcome(key: String, id: String) -> bool:
	if id == World.OUTCOME_IDS[0] or not World.OUTCOME_IDS.has(id):
		return false
	return key != WHEN_OUTCOMES_WON or id.begins_with(WIN_PREFIX)


static func _is_whole(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and float(value) == floorf(float(value))


# --------------------------------------------------------------- evaluating


static func _has_run_key(def: AchievementDef) -> bool:
	for key: String in RUN_KEYS:
		if def.when.has(key):
			return true
	return false


static func _totals_cover(def: AchievementDef, totals: Dictionary[String, Array]) -> bool:
	for tab: Variant in def.when[WHEN_CODEX_ALL]:
		if not totals.has(str(tab)):
			return false
	return true


static func _holds(def: AchievementDef, profile: Dictionary, run: Dictionary,
		totals: Dictionary[String, Array]) -> bool:
	for key: String in def.when:
		if not _key_holds(key, def.when[key], profile, run, totals):
			return false
	return true


static func _key_holds(key: String, value: Variant, profile: Dictionary, run: Dictionary,
		totals: Dictionary[String, Array]) -> bool:
	match key:
		WHEN_RUNS_COMPLETED:
			return _whole(profile, PROFILE_RUNS) >= int(value)
		WHEN_RUNS_WON:
			return _whole(profile, PROFILE_WON) >= int(value)
		WHEN_ENDINGS_SEEN:
			return _list(profile, PROFILE_ENDINGS_SEEN).size() >= int(value)
		WHEN_OUTCOMES_WON, WHEN_ARCHITECTURES_WON:
			for id: Variant in value:
				if not _won_one(key, str(id), profile):
					return false
			return true
		WHEN_CODEX_ALL:
			for tab: Variant in value:
				var seen: Array = _codex_tab(profile, str(tab))
				for id: Variant in totals.get(str(tab), []):
					if not seen.has(id):
						return false
			return true
		WHEN_WON:
			return typeof(run.get(FACT_WON)) == TYPE_BOOL and bool(run[FACT_WON])
		WHEN_OUTCOME:
			return _fact_in(run, FACT_OUTCOME, value)
		WHEN_VARIANT:
			return _fact_in(run, FACT_VARIANT, value)
		WHEN_ARCHITECTURE:
			return _fact_in(run, FACT_ARCHITECTURE, value)
		WHEN_DIFFICULTY:
			return _fact_in(run, FACT_DIFFICULTY, value)
		WHEN_SCENARIO:
			return _fact_in(run, FACT_SCENARIO, value)
		WHEN_DIRECTIVES_MIN:
			return _list(run, FACT_DIRECTIVES).size() >= int(value)
		WHEN_DAYS_MAX:
			return run.has(FACT_DAYS) and _whole(run, FACT_DAYS) <= int(value)
		WHEN_FLAG:
			var flags: Array = _list(run, FACT_FLAGS)
			for flag: Variant in value:
				if not flags.has(str(flag)):
					return false
			return true
	return false


## A win by that outcome, or with that architecture, is in the profile.
static func _won_one(key: String, id: String, profile: Dictionary) -> bool:
	if key == WHEN_OUTCOMES_WON:
		var by_outcome: Variant = profile.get(PROFILE_WINS_BY_OUTCOME)
		return typeof(by_outcome) == TYPE_DICTIONARY \
			and _whole(by_outcome as Dictionary, id) >= 1
	var by_architecture: Variant = profile.get(PROFILE_BY_ARCHITECTURE)
	if typeof(by_architecture) != TYPE_DICTIONARY:
		return false
	var row: Variant = (by_architecture as Dictionary).get(id)
	return typeof(row) == TYPE_DICTIONARY and _whole(row as Dictionary, PROFILE_ARCH_WINS) >= 1


## The fact is a non-empty string the list names (`""` never matches).
static func _fact_in(run: Dictionary, fact: String, ids: Variant) -> bool:
	var value: String = str(run.get(fact, ""))
	return not value.is_empty() and (ids as Array).has(value)


static func _codex_tab(profile: Dictionary, tab: String) -> Array:
	var codex: Variant = profile.get(PROFILE_CODEX)
	if typeof(codex) != TYPE_DICTIONARY:
		return []
	return _list(codex as Dictionary, tab)


static func _whole(d: Dictionary, key: String) -> int:
	var type: int = typeof(d.get(key))
	if type != TYPE_INT and type != TYPE_FLOAT:
		return 0
	return int(d[key])


static func _list(d: Dictionary, key: String) -> Array:
	return d[key] if typeof(d.get(key)) == TYPE_ARRAY else []
