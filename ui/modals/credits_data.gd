class_name CreditsData
extends RefCounted
## `data/credits.json`, read and checked (`docs/specs/icons.md` §11.3).
##
## Presentation data: the core never loads it. A bad file never crashes the
## title — `load_file` answers `{data, error}` and the screen shows what it can.
##
## An entry is shown only when its `requires` file ships, so the credits never
## name what is not in the build; `rows` ties it to `docs/ASSET_LICENCES.md`
## (§11.4, `test_credits_cover_licences.gd`).

const PATH: String = "res://data/credits.json"
const KEY_DATA: String = "data"
const KEY_ERROR: String = "error"
const VERSION: int = 1

const ROOT_KEYS: Array[String] = ["version", "made_by", "sections", "authors"]
const SECTION_KEYS: Array[String] = ["id", "entries"]
const ENTRY_KEYS: Array[String] = ["id", "name", "by", "role", "licence", "url", "requires",
	"text", "line", "rows"]
const AUTHOR_KEYS: Array[String] = ["name", "url"]
## §11.3: the licences an entry may name; each has `UI_CREDITS_LICENCE_<ID>`.
const LICENCES: Array[String] = ["mit", "ofl_1_1", "cc_by_3_0", "public_domain", "cc0_1_0",
	"apache_2_0"]

## `text`: the licence page an entry opens (§11.2). "" = no button.
const TEXT_NONE: String = ""
const TEXT_ENGINE: String = "engine"
const TEXT_GAME_ICONS: String = "game_icons"

const PREFIX_SECTION: String = "UI_CREDITS_SECTION_"
const PREFIX_LICENCE: String = "UI_CREDITS_LICENCE_"
const RES_PREFIX: String = "res://"
## Game-icons live one folder per author (§11.5).
const GAME_ICONS_ROOT: String = "res://assets/icons/game-icons"
const ICON_EXTENSION: String = ".svg"
const LOCALE_SOURCE: String = "en"
const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"

static var _id_regex: RegEx = RegEx.create_from_string(ID_PATTERN)


## Reads and checks the file at `path`. `data` is the parsed file (empty when it
## could not be read at all), `error` "" or every problem found, one per line.
static func load_file(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {KEY_DATA: {}, KEY_ERROR: "%s: missing" % path}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {KEY_DATA: {}, KEY_ERROR: "%s:%d: %s" % [path, json.get_error_line(),
			json.get_error_message()]}
	var errors: PackedStringArray = validate(json.data)
	var data: Dictionary = json.data if typeof(json.data) == TYPE_DICTIONARY else {}
	return {KEY_DATA: data, KEY_ERROR: "\n".join(errors)}


## Every problem with `raw`, as `path: message`. `has_string` answers whether a
## key is in the string table; by default the English translation is asked.
static func validate(raw: Variant, has_string: Callable = Callable()) -> PackedStringArray:
	if not has_string.is_valid():
		has_string = CreditsData.has_string_key
	var errors: PackedStringArray = []
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("credits: expected an object")
		return errors
	var d: Dictionary = raw
	_check_keys(d, ROOT_KEYS, "", errors)
	for key: String in ROOT_KEYS:
		if not d.has(key):
			errors.append("%s: missing required field" % key)
	if d.has("version"):
		var number: bool = typeof(d["version"]) == TYPE_FLOAT or typeof(d["version"]) == TYPE_INT
		if not number or int(d["version"]) != VERSION:
			errors.append("version: expected %d" % VERSION)
	if d.has("made_by"):
		_check_strings(d["made_by"], "made_by", errors)
	if d.has("sections"):
		_check_sections(d["sections"], has_string, errors)
	if d.has("authors"):
		_check_authors(d["authors"], errors)
	return errors


## Whether `key` has an English string — the table the game ships (§11.3).
static func has_string_key(key: String) -> bool:
	var table: Translation = TranslationServer.get_translation_object(LOCALE_SOURCE)
	return table != null and not String(table.get_message(StringName(key))).is_empty()


## Whether a `res://` file ships: a plain file (a licence text) or an imported
## resource (a texture, whose source is not in an exported build).
static func file_exists(path: String) -> bool:
	return not path.is_empty() and (FileAccess.file_exists(path) or ResourceLoader.exists(path))


## §11.3: an entry without `requires` always shows; one with it only when the
## file is there.
static func is_visible(entry: Dictionary) -> bool:
	var requires: String = str(entry.get("requires", ""))
	return requires.is_empty() or file_exists(requires)


## The entries of `section` that show, in file order.
static func visible_entries(section: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in section.get("entries", []):
		if typeof(entry) == TYPE_DICTIONARY and is_visible(entry):
			out.append(entry)
	return out


## The sections with at least one visible entry, in file order.
static func visible_sections(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for section: Variant in data.get("sections", []):
		if typeof(section) == TYPE_DICTIONARY and not visible_entries(section).is_empty():
			out.append(section)
	return out


## The `ASSET_LICENCES.md` ids the visible entries credit (§11.4).
static func credited_rows(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for section: Dictionary in visible_sections(data):
		for entry: Dictionary in visible_entries(section):
			for row: Variant in entry.get("rows", []):
				out.append(str(row))
	return out


## The author folder of a game-icons path ("…/game-icons/lorc/wheat.svg" →
## "lorc"), "" for any other path.
static func author_of(path: String) -> String:
	return Icons.author_of(path)


## Every game-icons file that ships, as `res://` paths. Only the icons the game
## uses are vendored (S6.4; `vendor_icons.py` deletes what the map no longer
## names), so what is in the folder is what is used.
static func used_icon_paths(root: String = GAME_ICONS_ROOT) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(root):
		return out
	for name: String in ResourceLoader.list_directory(root):
		if not name.ends_with("/"):
			continue
		var folder: String = root.path_join(name.trim_suffix("/"))
		for file: String in ResourceLoader.list_directory(folder):
			if file.ends_with(ICON_EXTENSION):
				out.append(folder.path_join(file))
	out.sort()
	return out


## Author folder → the icon names used from it (file names without `.svg`,
## sorted), for the authors line and the licence page (§11.5).
static func icons_by_author(paths: Array[String]) -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	for path: String in paths:
		var author: String = author_of(path)
		if author.is_empty():
			continue
		if not out.has(author):
			out[author] = []
		out[author].append(path.get_file().trim_suffix(ICON_EXTENSION))
	for author: String in out:
		out[author].sort()
	return out


## The display names of the authors in `folders`, sorted; a folder the file
## does not list is left out here and fails `test_every_used_author_is_listed`.
static func author_names(data: Dictionary, folders: Array[String]) -> Array[String]:
	var authors: Dictionary = data.get("authors", {})
	var out: Array[String] = []
	for folder: String in folders:
		if authors.has(folder):
			out.append(str((authors[folder] as Dictionary).get("name", folder)))
	out.sort()
	return out


static func _check_sections(raw: Variant, has_string: Callable,
		errors: PackedStringArray) -> void:
	if typeof(raw) != TYPE_ARRAY:
		errors.append("sections: expected a list")
		return
	var entry_ids: Dictionary[String, bool] = {}
	var section_ids: Dictionary[String, bool] = {}
	var sections: Array = raw
	for i: int in sections.size():
		var path: String = "sections[%d]" % i
		if typeof(sections[i]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % path)
			continue
		var s: Dictionary = sections[i]
		_check_keys(s, SECTION_KEYS, path, errors)
		var id: String = _id(s, "id", path, errors)
		if not id.is_empty():
			if section_ids.has(id):
				errors.append("%s.id: duplicate section \"%s\"" % [path, id])
			section_ids[id] = true
			_check_string(PREFIX_SECTION + id.to_upper(), path + ".id", has_string, errors)
		if typeof(s.get("entries")) != TYPE_ARRAY:
			errors.append("%s.entries: expected a list" % path)
			continue
		var entries: Array = s["entries"]
		for j: int in entries.size():
			_check_entry(entries[j], "%s.entries[%d]" % [path, j], entry_ids, has_string,
				errors)


static func _check_entry(raw: Variant, path: String, ids: Dictionary[String, bool],
		has_string: Callable, errors: PackedStringArray) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("%s: expected an object" % path)
		return
	var e: Dictionary = raw
	_check_keys(e, ENTRY_KEYS, path, errors)
	for key: String in ENTRY_KEYS:
		if key == "rows":
			continue
		if not e.has(key):
			errors.append("%s.%s: missing required field" % [path, key])
		elif typeof(e[key]) != TYPE_STRING:
			errors.append("%s.%s: expected a string" % [path, key])
	var id: String = _id(e, "id", path, errors)
	if not id.is_empty():
		if ids.has(id):
			errors.append("%s.id: duplicate entry \"%s\"" % [path, id])
		ids[id] = true
	if str(e.get("name", "")).is_empty():
		errors.append("%s.name: must not be empty" % path)
	_check_string(str(e.get("role", "")), path + ".role", has_string, errors)
	var licence: String = str(e.get("licence", ""))
	if not LICENCES.has(licence):
		errors.append("%s.licence: \"%s\" is not one of %s" % [path, licence, LICENCES])
	else:
		_check_string(PREFIX_LICENCE + licence.to_upper(), path + ".licence", has_string, errors)
	var requires: String = str(e.get("requires", ""))
	if not requires.is_empty() and not _is_res_path(requires):
		errors.append("%s.requires: \"%s\" is not a res:// file path" % [path, requires])
	var text: String = str(e.get("text", ""))
	if not [TEXT_NONE, TEXT_ENGINE, TEXT_GAME_ICONS].has(text) and not _is_res_path(text):
		errors.append("%s.text: \"%s\" is neither a page kind nor a res:// file path"
			% [path, text])
	var line: String = str(e.get("line", ""))
	if not line.is_empty():
		_check_string(line, path + ".line", has_string, errors)
	if not e.has("rows"):
		errors.append("%s.rows: missing required field" % path)
	else:
		_check_strings(e["rows"], path + ".rows", errors)


static func _check_authors(raw: Variant, errors: PackedStringArray) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("authors: expected an object")
		return
	var authors: Dictionary = raw
	for folder: Variant in authors:
		var path: String = "authors.%s" % str(folder)
		if typeof(authors[folder]) != TYPE_DICTIONARY:
			errors.append("%s: expected an object" % path)
			continue
		var a: Dictionary = authors[folder]
		_check_keys(a, AUTHOR_KEYS, path, errors)
		for key: String in AUTHOR_KEYS:
			if typeof(a.get(key)) != TYPE_STRING:
				errors.append("%s.%s: expected a string" % [path, key])
		if str(a.get("name", "")).is_empty():
			errors.append("%s.name: must not be empty" % path)


## Keys starting with `_` are comments (§11.3).
static func _check_keys(d: Dictionary, allowed: Array[String], path: String,
		errors: PackedStringArray) -> void:
	for raw_key: Variant in d.keys():
		var key: String = str(raw_key)
		if key.begins_with("_"):
			continue
		if not allowed.has(key):
			errors.append("%s: unknown field" % (key if path.is_empty() else path + "." + key))


static func _check_strings(raw: Variant, path: String, errors: PackedStringArray) -> void:
	if typeof(raw) != TYPE_ARRAY:
		errors.append("%s: expected a list" % path)
		return
	for value: Variant in raw:
		if typeof(value) != TYPE_STRING:
			errors.append("%s: expected strings only" % path)
			return


static func _check_string(key: String, path: String, has_string: Callable,
		errors: PackedStringArray) -> void:
	if key.is_empty() or not bool(has_string.call(key)):
		errors.append("%s: no string \"%s\" in the table" % [path, key])


static func _id(d: Dictionary, key: String, path: String, errors: PackedStringArray) -> String:
	var value: String = str(d.get(key, ""))
	if typeof(d.get(key)) != TYPE_STRING or _id_regex.search(value) == null:
		errors.append("%s.%s: \"%s\" is not a valid id" % [path, key, value])
		return ""
	return value


## A well-formed `res://` file path: no parent steps, no trailing slash.
static func _is_res_path(path: String) -> bool:
	return path.begins_with(RES_PREFIX) and path.length() > RES_PREFIX.length() \
		and not path.contains("..") and not path.ends_with("/") and not path.contains("\\")
