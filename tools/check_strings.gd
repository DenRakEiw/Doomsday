extends SceneTree
## Fails when a string is missing: a key the code or a scene names and the table
## lacks, an empty cell in either language, placeholders that differ between
## the two, a row that is there twice, or content whose keys the loader cannot
## find (UI.md §4 "Localisation", SCHEMA §9). `tools/test.sh` runs it after the
## script check; see docs/IMPLEMENTATION.md §2.
##
##     "$GODOT" --headless --path . -s tools/check_strings.gd

const Scan := preload("res://tools/string_scan.gd")


func _init() -> void:
	var findings: PackedStringArray = Scan.findings()
	if findings.is_empty():
		var duplicates: Array[String] = []
		var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
			duplicates)
		print("check_strings: %d rows, %d keys named in code and scenes, all in both languages."
			% [table.size(), Scan.code_keys(StringTable.domains(table)).size()])
		quit(0)
		return
	print("check_strings: %d findings:" % findings.size())
	for finding: String in findings:
		print("  %s" % finding)
	quit(1)
