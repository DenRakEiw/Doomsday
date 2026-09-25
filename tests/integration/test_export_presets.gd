extends GutTest
## S6.10 — the export presets and the project settings of release.md §5–§6.
##
## §6.2's rule: a new `FileAccess` read of a non-resource file under `res://` adds
## its pattern to the presets' include filter **and** to `RUNTIME_READS` here in
## the same commit. The scan below finds every such literal in `game/`, `ui/` and
## `core/` and fails on one that is neither listed nor covered.

const PRESETS: String = "res://export_presets.cfg"
const SECTION_PREFIX: String = "preset."
const OPTIONS_SUFFIX: String = ".options"
## §6.1: name → [platform, export path].
const EXPECTED: Dictionary[String, Array] = {
	"Windows": ["Windows Desktop", "build/windows/Doomsday.exe"],
	"Linux": ["Linux", "build/linux/Doomsday.x86_64"],
	"Web": ["Web", "build/web/index.html"],
	"Perf (local)": ["Windows Desktop", "build/perf/Doomsday-perf.exe"],
}
## The three CI builds.
const SHIPPED: Array[String] = ["Windows", "Linux", "Web"]
const PERF: String = "Perf (local)"
## §6.2: every shipped preset excludes these.
const EXCLUDES: Array[String] = ["tests/*", "tools/*", "addons/gut/*", "ui/dev/*", "docs/*",
	"*.md", "steam_appid.txt", ".github/*"]
## §6.2 plus the vendored icon licences (S6.10, *Deviations*); from S6.13 the
## shipped benchmark runs and the shipped copy of the global leaderboard.
const INCLUDES: Array[String] = ["data/*.json", "assets/licences/*.txt", "assets/fonts/*.txt",
	"assets/icons/*.txt", "benchmark/showcase/*.json", "benchmark/global/*.json"]
## The non-resource files the game reads at run time. The content root's files
## (`Game.CONTENT_ROOT`) are all JSON under `data/`.
const RUNTIME_READS: Array[String] = [
	"res://data/balance.json",
	"res://data/world/regions.json",
	"res://data/tech/infiltration.json",
	"res://data/achievements.json",
	"res://data/audio.json",
	"res://data/credits.json",
	"res://data/help.json",
	"res://data/icons.json",
	# S6.12: `BenchConfig`; the game's benchmark list reads it from S6.13 on.
	"res://data/benchmark.json",
	# S6.13: the shipped copy of the global leaderboard (`GlobalBoardClient`).
	"res://benchmark/global/leaderboard.json",
	"res://assets/licences/CC-BY-3.0.txt",
	"res://assets/icons/game-icons/license.txt",
	"res://assets/icons/phosphor/LICENSE.txt",
	"res://assets/fonts/OFL-JetBrainsMono.txt",
	"res://assets/fonts/OFL-SpaceGrotesk.txt",
]
## Read, but not needed in an export: the pseudo-locale is debug-only (§7) and
## the content loader skips its string check without the table (§6.2).
const NOT_SHIPPED: Array[String] = ["res://data/loc/strings.csv"]
const SCAN_ROOTS: Array[String] = ["res://game", "res://ui", "res://core"]
const LITERAL: String = "\"(res://[^\"]+\\.(json|txt|csv|cfg))\""
const VERSION_PATTERN: String = "^\\d+\\.\\d+\\.\\d+$"
const CREDITS: String = "res://data/credits.json"

var _config: ConfigFile = ConfigFile.new()
## Name → its section.
var _sections: Dictionary[String, String] = {}


func before_all() -> void:
	assert_eq(_config.load(PRESETS), OK, "export_presets.cfg parses")
	for section: String in _config.get_sections():
		if section.begins_with(SECTION_PREFIX) and not section.ends_with(OPTIONS_SUFFIX):
			_sections[str(_config.get_value(section, "name", ""))] = section


func test_the_presets_have_their_names_platforms_and_paths() -> void:
	assert_eq(_sections.size(), EXPECTED.size())
	for preset_name: String in EXPECTED:
		assert_true(_sections.has(preset_name), preset_name)
		if not _sections.has(preset_name):
			continue
		var section: String = _sections[preset_name]
		assert_eq(str(_config.get_value(section, "platform")), str(EXPECTED[preset_name][0]))
		assert_eq(str(_config.get_value(section, "export_path")), str(EXPECTED[preset_name][1]))
		assert_eq(str(_config.get_value(section, "export_filter")), "all_resources")


func test_the_shipped_presets_are_runnable_and_perf_is_not() -> void:
	for preset_name: String in SHIPPED:
		assert_true(bool(_config.get_value(_sections[preset_name], "runnable")), preset_name)
	assert_false(bool(_config.get_value(_sections[PERF], "runnable")))
	assert_eq(str(_config.get_value(_sections[PERF], "custom_features")), "perf")


func test_every_shipped_preset_excludes_the_development_files() -> void:
	for preset_name: String in SHIPPED:
		var excludes: Array[String] = _filters(preset_name, "exclude_filter")
		for pattern: String in EXCLUDES:
			assert_true(excludes.has(pattern), "%s excludes %s" % [preset_name, pattern])


func test_perf_keeps_tools_perf_and_drops_the_rest() -> void:
	var excludes: Array[String] = _filters(PERF, "exclude_filter")
	assert_true(excludes.has("steam_appid.txt"))
	assert_false(_matches_any("tools/perf/perf_bench.tscn", excludes))
	for path: String in ["tools/sim_run.gd", "tools/map/build_map.py", "tests/unit/test_smoke.gd",
			"addons/gut/gut.gd", "ui/dev/gallery.tscn"]:
		assert_true(_matches_any(path, excludes), path)


func test_every_preset_includes_the_runtime_files() -> void:
	for preset_name: String in EXPECTED:
		var includes: Array[String] = _filters(preset_name, "include_filter")
		for pattern: String in INCLUDES:
			assert_true(includes.has(pattern), "%s includes %s" % [preset_name, pattern])


func test_every_runtime_read_is_included_and_not_excluded() -> void:
	var includes: Array[String] = _filters("Windows", "include_filter")
	var excludes: Array[String] = _filters("Windows", "exclude_filter")
	var paths: Array[String] = RUNTIME_READS.duplicate()
	paths.append_array(_credits_files())
	for path: String in paths:
		var relative: String = path.trim_prefix("res://")
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		assert_true(_matches_any(relative, includes), "%s is included" % path)
		assert_false(_matches_any(relative, excludes), "%s is not excluded" % path)


func test_the_scan_finds_no_unlisted_runtime_read() -> void:
	var listed: Array[String] = RUNTIME_READS.duplicate()
	listed.append_array(NOT_SHIPPED)
	var regex: RegEx = RegEx.create_from_string(LITERAL)
	for script_path: String in _scripts():
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(script_path)):
			var path: String = found.get_string(1)
			assert_true(listed.has(path), "%s reads %s — add it to RUNTIME_READS" % [
				script_path, path])


func test_the_web_preset_is_single_threaded() -> void:
	var options: String = _sections["Web"] + OPTIONS_SUFFIX
	assert_false(bool(_config.get_value(options, "variant/thread_support")))
	assert_false(bool(_config.get_value(options, "progressive_web_app/enabled")))


func test_the_desktop_presets_embed_the_pack() -> void:
	for preset_name: String in ["Windows", "Linux", PERF]:
		var options: String = _sections[preset_name] + OPTIONS_SUFFIX
		assert_true(bool(_config.get_value(options, "binary_format/embed_pck")), preset_name)


func test_the_version_is_numeric() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	assert_not_null(RegEx.create_from_string(VERSION_PATTERN).search(version), version)


func test_the_game_has_its_own_user_folder() -> void:
	assert_true(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir")))
	assert_eq(str(ProjectSettings.get_setting("application/config/custom_user_dir_name")),
		"Doomsday")


func test_the_app_icon_exists() -> void:
	var icon: String = str(ProjectSettings.get_setting("application/config/icon", ""))
	assert_true(ResourceLoader.exists(icon), icon)


func _filters(preset_name: String, key: String) -> Array[String]:
	var out: Array[String] = []
	for part: String in str(_config.get_value(_sections[preset_name], key, "")).split(","):
		if not part.strip_edges().is_empty():
			out.append(part.strip_edges())
	return out


## Godot's filter match: `*` matches any run of characters, `/` included.
static func _matches_any(path: String, patterns: Array[String]) -> bool:
	for pattern: String in patterns:
		if path.matchn(pattern):
			return true
	return false


## The licence texts the credits read (`requires`/`text` of each entry).
static func _credits_files() -> Array[String]:
	var out: Array[String] = []
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(CREDITS)) != OK:
		return out
	_collect_txt(json.data, out)
	return out


static func _collect_txt(value: Variant, out: Array[String]) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var d: Dictionary = value
		for key: Variant in d:
			_collect_txt(d[key], out)
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			_collect_txt(item, out)
	elif typeof(value) == TYPE_STRING:
		var text: String = str(value)
		if text.begins_with("res://") and text.ends_with(".txt") and not out.has(text):
			out.append(text)


static func _scripts() -> Array[String]:
	var out: Array[String] = []
	for root: String in SCAN_ROOTS:
		_walk(root, out)
	return out


static func _walk(dir: String, out: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			out.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(sub), out)
