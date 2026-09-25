class_name HelpPages
extends RefCounted
## The Codex's *How to play* pages, `data/help.json` (`first-run.md` §6.5).
##
## Presentation data: the core never loads it. The file names each page, how many
## paragraphs it has, which coach steps and hints its *More* answers and which
## surfaces its `F1` and **?** open it from; the text is in `strings.csv`. A bad
## file never crashes: the help tab lists nothing and a warning names the errors
## (the shipped file is held to the rules by `test_help_pages.gd`).
##
## Never instantiated; a namespace of static functions over one cached read.

const PATH: String = "res://data/help.json"
const VERSION: int = 1
## The surfaces that have a page of their own (§6.7).
const CONTEXT_SESSION: String = "session"
const CONTEXT_REGION: String = "region"
const CONTEXT_TREE: String = "tree"
const CONTEXT_ABILITIES: String = "abilities"
const CONTEXT_CONTAINMENT: String = "containment"
const CONTEXT_ANALYSIS: String = "analysis"
const CONTEXTS: Array[String] = [CONTEXT_SESSION, CONTEXT_REGION, CONTEXT_TREE,
	CONTEXT_ABILITIES, CONTEXT_CONTAINMENT, CONTEXT_ANALYSIS]
const PARAGRAPHS_MIN: int = 1
const PARAGRAPHS_MAX: int = 6

const FIELD_VERSION: String = "version"
const FIELD_PAGES: String = "pages"
const FIELD_ID: String = "id"
const FIELD_PARAGRAPHS: String = "paragraphs"
const FIELD_COACH: String = "coach"
const FIELD_CONTEXTS: String = "contexts"
const KEY_TITLE: String = "HELP_%s_TITLE"
const KEY_PARAGRAPH: String = "HELP_%s_P%d"
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"

static var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)
static var _loaded: bool = false
static var _errors: Array[String] = []
static var _ids: Array[String] = []
static var _paragraphs: Dictionary[String, int] = {}
static var _by_step: Dictionary[String, String] = {}
static var _by_context: Dictionary[String, String] = {}


## Reads `path` (tests pass a fixture) and clears the cache; false with `errors()`
## filled when bad.
static func load_file(path: String = PATH) -> bool:
	_loaded = true
	_errors = []
	_ids = []
	_paragraphs = {}
	_by_step = {}
	_by_context = {}
	var raw: Variant = null
	if not FileAccess.file_exists(path):
		_errors.append("%s: missing" % path)
	else:
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			_errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		else:
			raw = json.data
	if _errors.is_empty():
		_read(raw)
	if not _errors.is_empty():
		# Nothing half-read is shown: the tab lists nothing rather than a guess.
		_ids = []
		_paragraphs = {}
		_by_step = {}
		_by_context = {}
		push_warning("help pages: %s" % "; ".join(_errors))
		return false
	return true


static func errors() -> Array[String]:
	_ensure()
	return _errors.duplicate()


## The pages in list order; [] when the file is bad.
static func ids() -> Array[String]:
	_ensure()
	return _ids.duplicate()


static func paragraphs(id: String) -> int:
	_ensure()
	return int(_paragraphs.get(id, 0))


static func title_key(id: String) -> String:
	return KEY_TITLE % id.to_upper()


## `n` counts from 1.
static func paragraph_key(id: String, n: int) -> String:
	return KEY_PARAGRAPH % [id.to_upper(), n]


## The page a coach step's or hint's *More* opens; "" when no page names it.
static func page_for_step(step: String) -> String:
	_ensure()
	return str(_by_step.get(step, ""))


## The page `F1` and the **?** open on `context`; "" when none.
static func page_for_context(context: String) -> String:
	_ensure()
	return str(_by_context.get(context, ""))


static func _ensure() -> void:
	if not _loaded:
		load_file()


## One message per broken rule (§6.5).
static func _read(raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		_errors.append("help: expected an object")
		return
	var d: Dictionary = raw
	var version_type: int = typeof(d.get(FIELD_VERSION))
	if (version_type != TYPE_INT and version_type != TYPE_FLOAT) \
			or int(d[FIELD_VERSION]) != VERSION:
		_errors.append("version: expected %d" % VERSION)
	if typeof(d.get(FIELD_PAGES)) != TYPE_ARRAY or (d[FIELD_PAGES] as Array).is_empty():
		_errors.append("pages: expected a non-empty array")
		return
	var pages: Array = d[FIELD_PAGES]
	for i: int in pages.size():
		_read_page(pages[i], "pages[%d]" % i)


static func _read_page(raw: Variant, where: String) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		_errors.append("%s: expected an object" % where)
		return
	var page: Dictionary = raw
	var id: String = str(page.get(FIELD_ID, "")) \
		if typeof(page.get(FIELD_ID)) == TYPE_STRING else ""
	if _id_regex.search(id) == null:
		_errors.append("%s.id: expected a snake-case id" % where)
		return
	if _ids.has(id):
		_errors.append("%s.id: %s is on two pages" % [where, id])
		return
	_ids.append(id)
	var count_type: int = typeof(page.get(FIELD_PARAGRAPHS))
	var count: int = int(page[FIELD_PARAGRAPHS]) \
		if count_type == TYPE_INT or count_type == TYPE_FLOAT else 0
	if count < PARAGRAPHS_MIN or count > PARAGRAPHS_MAX:
		_errors.append("%s.paragraphs: expected %d to %d" % [where, PARAGRAPHS_MIN,
			PARAGRAPHS_MAX])
	_paragraphs[id] = count
	for step: String in _strings(page, FIELD_COACH, where):
		if _by_step.has(step):
			_errors.append("%s.coach: %s is on two pages" % [where, step])
		else:
			_by_step[step] = id
	for context: String in _strings(page, FIELD_CONTEXTS, where):
		if not CONTEXTS.has(context):
			_errors.append("%s.contexts: unknown context %s" % [where, context])
		elif _by_context.has(context):
			_errors.append("%s.contexts: %s is on two pages" % [where, context])
		else:
			_by_context[context] = id


## A list of strings; missing is empty.
static func _strings(page: Dictionary, field: String, where: String) -> Array[String]:
	var out: Array[String] = []
	if not page.has(field):
		return out
	if typeof(page[field]) != TYPE_ARRAY:
		_errors.append("%s.%s: expected an array of strings" % [where, field])
		return out
	for value: Variant in page[field]:
		if typeof(value) != TYPE_STRING:
			_errors.append("%s.%s: expected an array of strings" % [where, field])
			continue
		out.append(str(value))
	return out
