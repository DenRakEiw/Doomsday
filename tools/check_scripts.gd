extends SceneTree
## Compiles every GDScript in the project and fails if any of them does not load.
##
## `--import` does not parse scripts at all, so a parse error — a warning that
## project.godot promotes to an error included — stays invisible until something
## happens to load that file. `tools/test.sh` runs this between the import and
## the test suite; see docs/IMPLEMENTATION.md §2.
##
##     "$GODOT" --headless --path . -s tools/check_scripts.gd
##
## `-s` starts no autoloads, so every script that names `Game` or `EventBus`
## fails here for a reason that is not a defect. Those are reported and skipped;
## `tests/unit/test_scripts_compile.gd` judges them inside the tree, where the
## autoloads exist.

const Scan := preload("res://tools/script_scan.gd")

## Names of the autoloads, which are identifiers no script can resolve in this
## main loop.
const AUTOLOAD_PREFIX: String = "autoload/"


func _init() -> void:
	var paths: PackedStringArray = Scan.collect()
	var autoloads: PackedStringArray = _autoload_names()

	var failed: PackedStringArray = []
	var deferred: PackedStringArray = []
	for path: String in paths:
		if Scan.compiles(path):
			continue
		if _names_an_autoload(path, autoloads):
			deferred.append(path)
		else:
			failed.append(path)

	if failed.is_empty():
		print("check_scripts: %d scripts compile, %d judged by the test suite."
			% [paths.size() - deferred.size(), deferred.size()])
		quit(0)
		return

	print("check_scripts: %d of %d scripts failed to compile:" % [failed.size(), paths.size()])
	for path: String in failed:
		print("  %s" % path)
	quit(1)


func _autoload_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for setting: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(setting.get("name", ""))
		if key.begins_with(AUTOLOAD_PREFIX):
			names.append(key.substr(AUTOLOAD_PREFIX.length()))
	return names


## Whether the file mentions an autoload by name, which is the one failure this
## main loop cannot tell from a defect. Text, not parsing: the script did not
## compile, so there is nothing to ask.
func _names_an_autoload(path: String, autoloads: PackedStringArray) -> bool:
	var source: String = FileAccess.get_file_as_string(path)
	for singleton_name: String in autoloads:
		if source.contains(singleton_name):
			return true
	return false
