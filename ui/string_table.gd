class_name StringTable
extends RefCounted
## The source rows of `data/loc/strings.csv` (SCHEMA §9), read as text.
##
## Godot imports the file as two translations and keeps nothing else, so what a
## check or the pseudo-locale needs — the keys, both columns side by side, the
## rows that are there twice — comes from here. The file is not part of an
## exported build; everything that reads it is a tool, a test or a debug switch.

const PATH: String = "res://data/loc/strings.csv"
const HEADER: PackedStringArray = ["keys", "en", "de"]
const COLUMN_EN: int = 0
const COLUMN_DE: int = 1

## A named placeholder, `{region}`; SCHEMA §9 forbids positional ones.
const PLACEHOLDER_PATTERN: String = "\\{[a-z_][a-z0-9_]*\\}"


## key → [en, de]. A key that appears twice keeps its first row and is added to
## `duplicates`. An unreadable file is an empty table and a pushed error.
static func read(path: String, duplicates: Array[String]) -> Dictionary[String, PackedStringArray]:
	var out: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("string table: cannot open %s" % path)
		return out
	var header: PackedStringArray = file.get_csv_line()
	if header != HEADER:
		push_error("string table: %s does not start with %s" % [path, ",".join(HEADER)])
		return out
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or row[0].strip_edges().is_empty():
			continue
		var key: String = row[0]
		if out.has(key):
			duplicates.append(key)
			continue
		var en: String = row[1] if row.size() > 1 else ""
		var de: String = row[2] if row.size() > 2 else ""
		out[key] = PackedStringArray([en, de])
	return out


## The named placeholders of a text, each once, sorted.
static func placeholders(text: String) -> PackedStringArray:
	var regex: RegEx = RegEx.create_from_string(PLACEHOLDER_PATTERN)
	var found: PackedStringArray = []
	for hit: RegExMatch in regex.search_all(text):
		if not found.has(hit.get_string()):
			found.append(hit.get_string())
	found.sort()
	return found


## The first segment of every key, `UI` for `UI_PAUSE_TITLE` — the domains of
## SCHEMA §9, as the table actually has them.
static func domains(table: Dictionary[String, PackedStringArray]) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	for key: String in table:
		out[key.get_slice("_", 0)] = true
	return out
