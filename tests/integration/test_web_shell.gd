extends GutTest
## S7.3 — the page the browser build starts from (web.md §5, §17.1): the
## exporter's placeholders, every `UI_WEB_*` string in both languages exactly as
## the string table has it, no request to any other host, one query key.

const SHELL: String = "res://web/shell.html"
const STRINGS: String = "res://data/loc/strings.csv"
const PREFIX: String = "UI_WEB_"
const COLUMN_EN: int = 1
const COLUMN_DE: int = 2
## What the shell reads from the address: `query.has('…')` or `query.get('…')`.
const QUERY_READ: String = "query\\.(has|get)\\('([^']*)'\\)"

var _shell: String = ""


func before_all() -> void:
	_shell = FileAccess.get_file_as_string(SHELL)


func test_the_shell_exists() -> void:
	assert_false(_shell.is_empty())


func test_the_shell_has_the_exporter_s_placeholders() -> void:
	for placeholder: String in ["$GODOT_URL", "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED"]:
		assert_string_contains(_shell, placeholder)


func test_every_web_string_appears_verbatim_in_both_languages() -> void:
	var rows: Array[PackedStringArray] = _web_rows()
	assert_gt(rows.size(), 0, "the table has UI_WEB_* rows")
	for row: PackedStringArray in rows:
		for column: int in [COLUMN_EN, COLUMN_DE]:
			var text: String = JSON.stringify(row[column])
			assert_string_contains(_shell, "\"%s\": %s" % [row[0], text])


func test_the_shell_names_no_other_host() -> void:
	assert_false(_shell.contains("http://"), "no http:// address")
	assert_false(_shell.contains("https://"), "no https:// address")


func test_the_shell_reads_one_query_key_smoke() -> void:
	var keys: Array[String] = []
	for found: RegExMatch in RegEx.create_from_string(QUERY_READ).search_all(_shell):
		keys.append(found.get_string(2))
	assert_eq(keys, ["smoke"] as Array[String])
	assert_eq(_shell.count("URLSearchParams"), 1, "the address is read once")


func _web_rows() -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	var file: FileAccess = FileAccess.open(STRINGS, FileAccess.READ)
	if file == null:
		return out
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > COLUMN_DE and row[0].begins_with(PREFIX):
			out.append(row)
	return out
