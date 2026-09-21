extends SceneTree
## Compiles every GDScript in the project and fails if any of them does not load.
##
## `--import` does not parse scripts at all, so a parse error — a warning that
## project.godot promotes to an error included — stays invisible until something
## happens to load that file. `tools/test.sh` runs this between the import and
## the test suite; see docs/IMPLEMENTATION.md §2.
##
##     "$GODOT" --headless --path . -s tools/check_scripts.gd

## Third-party code, exempt from our warning levels (`exclude_addons` in project.godot).
const SKIPPED_DIRS: PackedStringArray = ["res://addons"]


func _init() -> void:
	var paths: PackedStringArray = _collect_scripts("res://")
	paths.sort()

	var failed: PackedStringArray = []
	for path: String in paths:
		# The default cache mode, deliberately: CACHE_MODE_IGNORE re-parses this
		# very script while it is running, which corrupts the running function.
		# A script that is already cached compiled, which is all we ask.
		var script: GDScript = ResourceLoader.load(path, "GDScript") as GDScript
		# A parse error does not make the load fail — Godot hands back an empty
		# GDScript instead. The empty one has no native base type; every script
		# that compiled has one, an `@abstract` or an empty file included.
		if script == null or script.get_instance_base_type().is_empty():
			failed.append(path)

	if failed.is_empty():
		print("check_scripts: %d scripts compile." % paths.size())
		quit(0)
		return

	print("check_scripts: %d of %d scripts failed to compile:" % [failed.size(), paths.size()])
	for path: String in failed:
		print("  %s" % path)
	quit(1)


func _collect_scripts(dir_path: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("check_scripts: cannot open %s" % dir_path)
		return found

	dir.list_dir_begin()  # Hidden entries are skipped, which keeps .godot/ out.
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not SKIPPED_DIRS.has(path):
				found.append_array(_collect_scripts(path))
		elif entry.ends_with(".gd"):
			found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

	return found
