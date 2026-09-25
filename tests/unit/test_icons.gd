extends GutTest
## S6.4 — the icon map and `Icons` (docs/specs/icons.md §5, §6, §8, §13).

const Atlas := preload("res://tools/build_icon_atlas.gd")

const WORLD_ROOT: String = "res://data"
const FIXTURE_MAP: String = "user://icons_fixture.json"
const ATLAS_TEST_DIR: String = "user://atlas_test/"
const SET_FOLDERS: Array[String] = ["phosphor/", "game-icons/"]
const ROOTS: Array[String] = ["phosphor/", "game-icons/", "custom/"]

static var _db: ContentDB = null


func before_all() -> void:
	if _db == null:
		var result: ContentLoadResult = ContentLoader.load_root(WORLD_ROOT)
		assert_true(result.ok(), result.error_text())
		_db = result.db


func after_each() -> void:
	Icons.load_map(Icons.MAP_PATH)
	Icons.load_atlas(Icons.ATLAS_DIR)
	if FileAccess.file_exists(FIXTURE_MAP):
		DirAccess.remove_absolute(FIXTURE_MAP)


func test_map_covers_every_glyph() -> void:
	var expected: Array[String] = []
	expected.assign(Glyphs.Glyph.keys())
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_GLYPH)), _sorted(expected))


func test_map_covers_every_content_id() -> void:
	var tech: Array[String] = []
	for def: TechNodeDef in _db.tech_nodes:
		tech.append(def.id)
	var abilities: Array[String] = []
	for def: AbilityDef in _db.abilities:
		abilities.append(def.id)
	var statuses: Array[String] = []
	for def: StatusDef in _db.statuses:
		statuses.append(def.id)
	var factions: Array[String] = []
	for def: FactionDef in _db.factions:
		factions.append(def.id)
	var architectures: Array[String] = []
	for def: ArchitectureDef in _db.architectures:
		architectures.append(def.id)
	var moves: Array[String] = []
	for def: EventDef in _db.events:
		if def.kind == EventDef.KIND_COUNTER_MOVE:
			moves.append(def.id)
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_TECH)), _sorted(tech))
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_ABILITY)), _sorted(abilities))
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_STATUS)), _sorted(statuses))
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_FACTION)), _sorted(factions))
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_ARCHITECTURE)), _sorted(architectures))
	assert_eq(_sorted_keys(Icons.section(Icons.KIND_COUNTER_MOVE)), _sorted(moves))


func test_every_mapped_path_resolves() -> void:
	var missing: Array[String] = []
	for kind: StringName in Icons.KINDS:
		var section: Dictionary = Icons.section(kind)
		for id: Variant in section:
			var value: String = str(section[id])
			var has_root: bool = false
			for root: String in ROOTS:
				has_root = has_root or value.begins_with(root)
			if not has_root or Icons.path_for(kind, str(id)).is_empty():
				missing.append("%s.%s" % [kind, id])
	assert_eq(missing, [] as Array[String])


func test_custom_paths_have_stand_ins() -> void:
	var stand_ins: Dictionary = Icons.stand_ins()
	var without: Array[String] = []
	for kind: StringName in Icons.KINDS:
		var section: Dictionary = Icons.section(kind)
		for id: Variant in section:
			var value: String = str(section[id])
			if value.begins_with(Icons.FOLDER_CUSTOM) \
					and not value.begins_with(Icons.FOLDER_CUSTOM_CHROME) \
					and not stand_ins.has(value):
				without.append(value)
	assert_eq(without, [] as Array[String])


func test_stand_ins_are_set_files() -> void:
	var stand_ins: Dictionary = Icons.stand_ins()
	assert_gt(stand_ins.size(), 0)
	for path: Variant in stand_ins:
		var stand_in: String = str(stand_ins[path])
		assert_true(stand_in.begins_with(SET_FOLDERS[0]) or stand_in.begins_with(SET_FOLDERS[1]),
			"%s stands in with a set file" % path)
		assert_true(ResourceLoader.exists(Icons.ROOT + stand_in), "%s ships" % stand_in)


func test_texture_has_requested_size() -> void:
	for size: int in [UiTokens.GLYPH_BOX, UiTokens.ICON_L]:
		var chrome: Texture2D = Icons.glyph_texture(Glyphs.Glyph.PAUSE, size)
		var illustrative: Texture2D = Icons.texture(Icons.KIND_TECH, "cloud_federation", size)
		assert_not_null(chrome)
		assert_not_null(illustrative)
		assert_eq(chrome.get_size(), Vector2(size, size))
		assert_eq(illustrative.get_size(), Vector2(size, size))


func test_unmapped_id_returns_null() -> void:
	assert_null(Icons.texture(Icons.KIND_TECH, "no_such_node", UiTokens.ICON_ROW))
	assert_eq(Icons.path_for(Icons.KIND_TECH, "no_such_node"), "")
	var canvas: Control = Control.new()
	add_child_autofree(canvas)
	assert_false(Icons.draw(canvas, Icons.KIND_TECH, "no_such_node", Rect2(0, 0, 20, 20),
		Color.WHITE))


func test_missing_file_falls_back_to_stand_in() -> void:
	_write_fixture({
		"version": 1,
		"tech": {"a": "custom/not_drawn.svg", "b": "custom/also_not_drawn.svg"},
		"stand_ins": {"custom/not_drawn.svg": "game-icons/lorc/wheat.svg",
			"custom/also_not_drawn.svg": "game-icons/lorc/not_there.svg"},
	})
	assert_eq(Icons.path_for(Icons.KIND_TECH, "a"), "game-icons/lorc/wheat.svg")
	assert_not_null(Icons.texture(Icons.KIND_TECH, "a", UiTokens.ICON_ROW))
	assert_eq(Icons.path_for(Icons.KIND_TECH, "b"), "",
		"neither the file nor its stand-in ships")
	# The real map: voluntary_pause's own silhouette failed D6.3's read test.
	Icons.load_map(Icons.MAP_PATH)
	assert_eq(Icons.path_for(Icons.KIND_TECH, "voluntary_pause"), "game-icons/lorc/hourglass.svg")


func test_glyph_without_file_draws_procedural() -> void:
	_write_fixture({"version": 1, "glyphs": {"PAUSE": "phosphor/not-there-fill.svg"}})
	assert_null(Icons.glyph_texture(Glyphs.Glyph.PAUSE, UiTokens.GLYPH_BOX))
	assert_null(Icons.glyph_texture(Glyphs.Glyph.PLAY, UiTokens.GLYPH_BOX), "unmapped")
	# The procedural shape draws without a texture and without an error.
	var icon: GlyphIcon = GlyphIcon.new()
	icon.glyph = Glyphs.Glyph.PAUSE
	add_child_autofree(icon)
	await get_tree().process_frame
	assert_engine_error_count(0)
	Icons.load_map(Icons.MAP_PATH)
	assert_not_null(Icons.glyph_texture(Glyphs.Glyph.PAUSE, UiTokens.GLYPH_BOX),
		"with the real map the file is drawn")


func test_author_of_parses_path() -> void:
	assert_eq(Icons.author_of("game-icons/lorc/wheat.svg"), "lorc")
	assert_eq(Icons.author_of("res://assets/icons/game-icons/delapouite/tv.svg"), "delapouite")
	assert_eq(Icons.author_of("phosphor/x-bold.svg"), "")
	assert_eq(Icons.author_of("custom/arch_swarm.svg"), "")


func test_atlas_builds_and_resolves() -> void:
	var result: Dictionary = Atlas.build(ATLAS_TEST_DIR)
	assert_eq(str(result["error"]), "")
	assert_gt(int(result["icons"]), 0)
	var before: Variant = ProjectSettings.get_setting(Icons.ATLAS_SETTING, false)
	ProjectSettings.set_setting(Icons.ATLAS_SETTING, true)
	Icons.load_atlas(ATLAS_TEST_DIR)
	var tex: Texture2D = Icons.texture(Icons.KIND_TECH, "cloud_federation", UiTokens.ICON_ROW)
	ProjectSettings.set_setting(Icons.ATLAS_SETTING, before)
	assert_true(tex is AtlasTexture, "the atlas answers with a region of a page")
	if tex is AtlasTexture:
		# 20 is built as such, at twice the size for a 2× screen.
		var region: Rect2 = (tex as AtlasTexture).region
		assert_eq(region.size, Vector2(UiTokens.ICON_ROW, UiTokens.ICON_ROW) * 2.0)
		assert_not_null((tex as AtlasTexture).atlas)
	for file: String in DirAccess.get_files_at(ATLAS_TEST_DIR):
		DirAccess.remove_absolute(ATLAS_TEST_DIR.path_join(file))
	DirAccess.remove_absolute(ATLAS_TEST_DIR)


func _write_fixture(map: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(FIXTURE_MAP, FileAccess.WRITE)
	file.store_string(JSON.stringify(map))
	file.close()
	Icons.load_map(FIXTURE_MAP)


static func _sorted_keys(section: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: Variant in section:
		out.append(str(key))
	out.sort()
	return out


static func _sorted(ids: Array[String]) -> Array[String]:
	var out: Array[String] = ids.duplicate()
	out.sort()
	return out


func test_icon_rect_hides_without_file() -> void:
	var icon: IconRect = IconRect.new()
	add_child_autofree(icon)
	icon.show_icon(Icons.KIND_STATUS, "lockdown")
	assert_true(icon.visible)
	icon.show_icon(Icons.KIND_STATUS, "no_such_status")
	assert_false(icon.visible, "a missing icon leaves no hole")
