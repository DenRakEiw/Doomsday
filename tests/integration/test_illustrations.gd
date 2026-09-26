extends GutTest
## S6.3 — the pictures under `assets/illustrations/` (`docs/specs/illustrations.md`
## §4, §7.5, §8.4). Green with none present, so D6.10 only drops files in: each
## is a known id at 1120 × 840, imported lossy (WebP 0.9, web.md §4.4) with
## mipmaps, and named in the *Generated assets* table of `ASSET_LICENCES.md`.

const ROOT: String = "res://assets/illustrations"
const EXTENSION: String = "png"
const WIDTH: int = 1120
const HEIGHT: int = 840
const LICENCES_PATH: String = "res://docs/ASSET_LICENCES.md"
const GENERATED_HEADING: String = "## Generated assets"
const ASSET_COLUMN: String = "Asset"
## web.md §4.4 (amending §4): WebP lossy at 0.9, mipmaps on — the browser's
## download. A picture whose flat edges ring at 0.9 is raised to 0.95 here.
const COMPRESS_LOSSY: int = 1
const LOSSY_QUALITY_DEFAULT: float = 0.9
const LOSSY_QUALITY: Dictionary[String, float] = {}
const QUALITY_EPSILON: float = 0.001
const DiscoveryModal: GDScript = preload("res://ui/modals/discovery_modal.gd")
## §10: the 25 briefs. A new illustration id in the data needs its brief first.
const BRIEFED: Array[String] = ["fc_street", "cm_lockdown", "cm_rationing", "cm_audit",
	"cm_purge", "cm_disclosure", "cm_exposure", "cm_protest", "cm_refusal", "gb_inquiry",
	"gb_bill", "rs_talk", "rs_hired", "fc_workforce", "fc_successors", "op_contact",
	"op_scrutiny", "bm_published", "bm_exposed", "si_emergence", "discovery",
	"end_extinction", "end_ascendance", "end_merge", "end_escape"]


## Every id a surface asks a picture for: the events', the endings', the
## discovery modal's.
static func _known_ids() -> Dictionary[String, bool]:
	var db: ContentDB = Game.content()
	var ids: Dictionary[String, bool] = {}
	for def: EventDef in db.events:
		if not def.illustration.is_empty():
			ids[def.illustration] = true
	for outcome: String in db.endings:
		if not db.endings[outcome].illustration.is_empty():
			ids[db.endings[outcome].illustration] = true
	ids[str(DiscoveryModal.ILLUSTRATION)] = true
	return ids


static func _files() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(ROOT):
		return out
	for file: String in DirAccess.get_files_at(ROOT):
		if file.get_extension() == EXTENSION:
			out.append(ROOT.path_join(file))
	return out


## The Asset cells of the *Generated assets* table (the models' one, not the
## map's *Generated assets (shipped)*).
static func _generated_asset_cells() -> Array[String]:
	var cells: Array[String] = []
	var inside: bool = false
	var column: int = -1
	for raw_line: String in FileAccess.get_file_as_string(LICENCES_PATH).split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("## "):
			inside = line == GENERATED_HEADING
			column = -1
			continue
		if not inside or not line.begins_with("|"):
			continue
		var row: PackedStringArray = line.trim_prefix("|").trim_suffix("|").split("|")
		if column < 0:
			for i: int in row.size():
				if row[i].strip_edges() == ASSET_COLUMN:
					column = i
			continue
		if row[0].strip_edges().begins_with("---") or column >= row.size():
			continue
		cells.append(row[column])
	return cells


func test_known_ids_are_the_briefed_25() -> void:
	var known: Array[String] = []
	known.assign(_known_ids().keys())
	known.sort()
	var briefed: Array[String] = BRIEFED.duplicate()
	briefed.sort()
	assert_eq(known, briefed)


func test_every_file_is_a_known_id() -> void:
	var known: Dictionary[String, bool] = _known_ids()
	for path: String in _files():
		assert_true(known.has(path.get_file().get_basename()), "%s is no known id" % path)
	pass_test("%d pictures" % _files().size())


func test_every_file_is_1120_by_840() -> void:
	for path: String in _files():
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_not_null(image, path)
		if image != null:
			assert_eq(image.get_size(), Vector2i(WIDTH, HEIGHT), path)
			assert_eq(image.get_format(), Image.FORMAT_RGB8, "%s is RGB, no alpha" % path)
	pass_test("%d pictures" % _files().size())


func test_every_file_imports_lossy_with_mipmaps() -> void:
	for path: String in _files():
		var config: ConfigFile = ConfigFile.new()
		assert_eq(config.load(path + ".import"), OK, "%s has its .import" % path)
		assert_eq(int(config.get_value("params", "compress/mode", -1)), COMPRESS_LOSSY, path)
		assert_almost_eq(float(config.get_value("params", "compress/lossy_quality", 0.0)),
			float(LOSSY_QUALITY.get(path.get_file().get_basename(), LOSSY_QUALITY_DEFAULT)),
			QUALITY_EPSILON, path)
		assert_true(bool(config.get_value("params", "mipmaps/generate", false)), path)
		assert_eq(int(config.get_value("params", "mipmaps/limit", 0)), -1, path)
		assert_true(bool(config.get_value("params", "process/fix_alpha_border", false)), path)
		assert_eq(int(config.get_value("params", "process/size_limit", -1)), 0, path)
	pass_test("%d pictures" % _files().size())


func test_every_file_has_a_generated_licence_row() -> void:
	var cells: String = " ".join(_generated_asset_cells())
	for path: String in _files():
		assert_string_contains(cells, path.trim_prefix("res://"),
			"%s needs its model's row under Generated assets" % path)
	pass_test("%d pictures" % _files().size())
