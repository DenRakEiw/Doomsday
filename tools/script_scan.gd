extends RefCounted
## Finds every GDScript in the project and says which of them do not compile.
##
## Two callers, because neither alone is enough: `tools/check_scripts.gd` runs
## this before the test suite and catches a parse error early, but `-s` gives it
## no autoloads, so every script that names `Game` or `EventBus` fails to compile
## there for a reason that is not a defect — and Godot still hands back a usable
## class, so the failure is invisible. `tests/unit/test_scripts_compile.gd` runs
## the same scan inside the tree, where the autoloads exist and the answer is
## true.
##
## A tool, so no `class_name`; both callers preload it.

## Third-party code, exempt from our warning levels (`exclude_addons` in project.godot).
const SKIPPED_DIRS: PackedStringArray = ["res://addons"]
const SCRIPT_SUFFIX: String = ".gd"
const HIDDEN_PREFIX: String = "."


static func collect(dir_path: String = "res://") -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("script_scan: cannot open %s" % dir_path)
		return found

	dir.list_dir_begin()  # Hidden entries are skipped, which keeps .godot/ out.
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			# A dot folder is never the game's: on Windows `.claude/` (an agent's
			# worktree, a whole second checkout) is not hidden to `DirAccess`.
			if not SKIPPED_DIRS.has(path) and not entry.begins_with(HIDDEN_PREFIX):
				found.append_array(collect(path))
		elif entry.ends_with(SCRIPT_SUFFIX):
			found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

	found.sort()
	return found


## The paths in `paths` that do not compile.
static func failures(paths: PackedStringArray) -> PackedStringArray:
	var failed: PackedStringArray = []
	for path: String in paths:
		if not compiles(path):
			failed.append(path)
	return failed


static func compiles(path: String) -> bool:
	# The default cache mode, deliberately: CACHE_MODE_IGNORE re-parses the
	# running script and corrupts it mid-run. A script that is already cached
	# compiled, which is all we ask.
	var script: GDScript = ResourceLoader.load(path, "GDScript") as GDScript
	if script == null:
		return false
	# A parse error does not always make the load fail — Godot hands back an
	# empty `GDScript` instead. The empty one has no native base type; every
	# script that compiled has one, an `@abstract` or an empty file included.
	if script.get_instance_base_type().is_empty():
		return false
	# A *compile* error is subtler still: the class keeps its base type and even
	# its member list, and only this says it was never built. Nothing in the
	# project is `@abstract`; the day something is, it must be exempted here.
	return script.can_instantiate()
