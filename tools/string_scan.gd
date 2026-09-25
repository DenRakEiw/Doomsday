extends RefCounted
## What the string check of S4.9 looks for (UI.md §4 "Localisation", SCHEMA §9).
##
## Three kinds of finding, each a line of text:
## - a row of `strings.csv` that is there twice, has an empty cell, or whose two
##   languages do not name the same placeholders;
## - a key that a script or a scene names and the table does not have;
## - a content file whose strings the loader finds missing (the loader checks
##   every content key already; this only asks it).
##
## A key is found as a quoted literal of capitals and underscores whose first
## segment is one of the table's domains. A key built at run time
## (`"UI_OUTCOME_%s"`) is invisible to this and is checked by the test of the
## class that builds it.
##
## Two callers: `tools/check_strings.gd` before the test suite, and
## `tests/integration/test_localisation.gd` inside it. A tool, so no `class_name`.

const SCANNED_DIRS: PackedStringArray = ["res://core", "res://game", "res://ui"]
const SUFFIXES: PackedStringArray = [".gd", ".tscn"]
const KEY_PATTERN: String = "(?<!&)\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\""
## Literals that look like keys and are not: glyph names from `assets.json`
## (`Glyphs.ASSET_NAMES`). A `StringName` literal, `&"STAT_PENETRATION"`, is a
## token or an enum name and is skipped by the pattern itself.
const NOT_KEYS: PackedStringArray = ["ASSET_FLEET", "ASSET_LAB", "ASSET_TAP", "ASSET_OFFICE"]
const CONTENT_ROOT: String = "res://data"


## Every finding, sorted; empty means the strings are complete.
static func findings() -> PackedStringArray:
	var duplicates: Array[String] = []
	var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
		duplicates)
	var out: PackedStringArray = []
	if table.is_empty():
		out.append("%s: no rows" % StringTable.PATH)
		return out
	out.append_array(row_findings(table, duplicates))
	out.append_array(missing_keys(table, code_keys(StringTable.domains(table))))
	var loaded: ContentLoadResult = ContentLoader.load_root(CONTENT_ROOT)
	if not loaded.ok():
		out.append("%s: %s" % [CONTENT_ROOT, loaded.error_text()])
	out.sort()
	return out


static func row_findings(table: Dictionary[String, PackedStringArray],
		duplicates: Array[String]) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in duplicates:
		out.append("%s: appears more than once" % key)
	for key: String in table:
		var en: String = table[key][StringTable.COLUMN_EN]
		var de: String = table[key][StringTable.COLUMN_DE]
		if en.strip_edges().is_empty() or de.strip_edges().is_empty():
			out.append("%s: a language is empty" % key)
			continue
		var en_names: PackedStringArray = StringTable.placeholders(en)
		var de_names: PackedStringArray = StringTable.placeholders(de)
		if en_names != de_names:
			out.append("%s: placeholders differ, en %s, de %s" % [key, en_names, de_names])
	return out


## key → the first file that names it.
static func code_keys(domains: Dictionary[String, bool]) -> Dictionary[String, String]:
	var regex: RegEx = RegEx.create_from_string(KEY_PATTERN)
	var out: Dictionary[String, String] = {}
	for dir: String in SCANNED_DIRS:
		for path: String in _collect(dir):
			var source: String = FileAccess.get_file_as_string(path)
			for hit: RegExMatch in regex.search_all(source):
				var key: String = hit.get_string(1)
				if domains.has(key.get_slice("_", 0)) and not NOT_KEYS.has(key) and not out.has(key):
					out[key] = path
	return out


static func missing_keys(table: Dictionary[String, PackedStringArray],
		keys: Dictionary[String, String]) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in keys:
		if not table.has(key):
			out.append("%s: named in %s, not in %s" % [key, keys[key], StringTable.PATH])
	return out


static func _collect(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			# As `script_scan.gd`: a dot folder is never the game's.
			if not entry.begins_with("."):
				found.append_array(_collect(path))
		else:
			for suffix: String in SUFFIXES:
				if entry.ends_with(suffix):
					found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
