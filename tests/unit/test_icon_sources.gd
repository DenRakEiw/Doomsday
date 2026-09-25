extends GutTest
## S6.4 — every shipped SVG under `assets/icons/` is normalised (docs/specs/icons.md
## §4, §5.1): white on nothing, the folder's grid, nothing Godot's SVG importer
## would drop, imported as a `DPITexture`.

const ROOT: String = "res://assets/icons"
const WHITE: String = "#FFFFFF"
const BACKGROUND: String = "M0 0h512v512H0z"
const FORBIDDEN: Array[String] = ["<text", "<filter", "<mask", "<image", "<use",
	"Gradient", "stroke"]

var _sources: Dictionary[String, String] = {}


func before_all() -> void:
	_collect(ROOT)


func test_sources_exist() -> void:
	# 25 Phosphor + 117 game-icons + 27 own (voluntary_pause kept its stand-in).
	assert_gt(_sources.size(), 160, "the vendored and own files are all there")


func test_sources_are_white() -> void:
	var colour: RegEx = RegEx.create_from_string("(fill|stroke)=\"([^\"]*)\"")
	for path: String in _sources:
		var text: String = _sources[path]
		assert_false(text.contains("currentColor"), "%s: currentColor" % path)
		for found: RegExMatch in colour.search_all(text):
			if found.get_string(1) == "fill" and found.get_string(2) == WHITE:
				continue
			fail_test("%s: %s=\"%s\"" % [path, found.get_string(1), found.get_string(2)])
		assert_true(text.contains("fill=\"%s\"" % WHITE), "%s draws in white" % path)


func test_sources_have_no_background() -> void:
	for path: String in _sources:
		assert_false(_sources[path].contains(BACKGROUND), "%s: background square" % path)


func test_sources_have_no_text_or_filters() -> void:
	for path: String in _sources:
		for token: String in FORBIDDEN:
			assert_false(_sources[path].contains(token), "%s: %s" % [path, token])


func test_view_box_matches_folder() -> void:
	var root_tag: RegEx = RegEx.create_from_string("<svg\\b[^>]*>")
	for path: String in _sources:
		var tag: RegExMatch = root_tag.search(_sources[path])
		assert_not_null(tag, "%s: an <svg> root" % path)
		if tag == null:
			continue
		var side: int = int(Icons.view_box_of(path.trim_prefix(ROOT + "/")))
		var expected: String = "viewBox=\"0 0 %d %d\"" % [side, side]
		assert_true(tag.get_string().contains(expected), "%s: %s" % [path, expected])
		assert_false(tag.get_string().contains(" width="), "%s: a fixed width" % path)
		assert_false(tag.get_string().contains(" height="), "%s: a fixed height" % path)


func test_sources_import_as_dpitexture() -> void:
	for path: String in _sources:
		var stub: String = FileAccess.get_file_as_string(path + ".import")
		assert_true(stub.contains("importer=\"svg\""), "%s imports with the svg importer" % path)
		assert_true(load(path) is DPITexture, "%s loads as a DPITexture" % path)


func _collect(dir: String) -> void:
	for name: String in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(name))
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".svg"):
			var path: String = dir.path_join(name)
			_sources[path] = FileAccess.get_file_as_string(path)
