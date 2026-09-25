class_name Icons
extends RefCounted
## The icon files, by id (docs/specs/icons.md §5.2).
##
## `data/icons.json` maps every `Glyphs` id and every content id that shows an
## icon to a white SVG under `assets/icons/`. This class resolves an id to its
## file (or the file's stand-in, §6), makes a `DPITexture` of it at the size it
## is drawn at, and draws it tinted. A missing map, a missing file or an
## unmapped id is never an error the player sees: the lookup returns null and
## the caller falls back — `Glyphs` to its procedural shape, everything else to
## no icon at all.
##
## Never instantiated; the caches are static.

const MAP_PATH: String = "res://data/icons.json"
const ROOT: String = "res://assets/icons/"
## A project setting, default false: the PNG atlas instead of `DPITexture`, for a
## platform where the latter misbehaves (VISUALS q5, §10.2).
const ATLAS_SETTING: String = "doomsday/icons/use_atlas"
const ATLAS_DIR: String = "res://assets/icons/atlas/"
const ATLAS_INDEX: String = "atlas.json"
const ATLAS_PAGE: String = "icons_%d.png"
## §10.2: the sizes the atlas is built at; a request takes the nearest one at
## least as large.
const ATLAS_SIZES: Array[int] = [12, 16, 20, 24, 48, 64, 96]
## The kinds are the sections of icons.json.
const KIND_GLYPH: StringName = &"glyphs"
const KIND_TECH: StringName = &"tech"
const KIND_ABILITY: StringName = &"abilities"
const KIND_STATUS: StringName = &"statuses"
const KIND_FACTION: StringName = &"factions"
const KIND_ARCHITECTURE: StringName = &"architectures"
const KIND_COUNTER_MOVE: StringName = &"counter_moves"
const KINDS: Array[StringName] = [KIND_GLYPH, KIND_TECH, KIND_ABILITY, KIND_STATUS,
	KIND_FACTION, KIND_ARCHITECTURE, KIND_COUNTER_MOVE]
const KEY_VERSION: String = "version"
const KEY_STAND_INS: String = "stand_ins"
## The three roots a mapped path may start with (§8).
const FOLDER_PHOSPHOR: String = "phosphor/"
const FOLDER_GAME_ICONS: String = "game-icons/"
const FOLDER_CUSTOM: String = "custom/"
const FOLDER_CUSTOM_CHROME: String = "custom/chrome/"
## §4: the chrome grid is Phosphor's, the illustrative one game-icons'.
const VIEW_BOX_CHROME: float = 256.0
const VIEW_BOX_ILLUSTRATIVE: float = 512.0

## kind → id → path, and "stand_ins" → path → path.
static var _map: Dictionary[String, Dictionary] = {}
static var _map_path: String = MAP_PATH
static var _is_loaded: bool = false
## "<path>@<size>" → the texture made for it (null when the file failed to load).
static var _textures: Dictionary[String, Texture2D] = {}
static var _atlas_dir: String = ATLAS_DIR
## size → path → [x, y, w, h]; read once per atlas directory.
static var _atlas_index: Dictionary[int, Dictionary] = {}
static var _atlas_pages: Dictionary[int, Texture2D] = {}
static var _is_atlas_read: bool = false


## The file an id resolves to, after stand-ins: "" when unmapped, or when neither
## the file nor its stand-in exists.
static func path_for(kind: StringName, id: String) -> String:
	_ensure_map()
	var section: Dictionary = _map.get(String(kind), {})
	if not section.has(id):
		return ""
	return _resolve(str(section[id]))


## A texture `size_px` square for the id, or null (the caller falls back).
## `size_px` is the logical size; `DPITexture` follows the viewport's
## oversampling itself, which is what keeps the icon crisp at 4K.
static func texture(kind: StringName, id: String, size_px: int) -> Texture2D:
	var path: String = path_for(kind, id)
	if path.is_empty() or size_px <= 0:
		return null
	if _uses_atlas():
		return _atlas_texture(path, size_px)
	var key: String = "%s@%d" % [path, size_px]
	if _textures.has(key):
		return _textures[key]
	var made: Texture2D = null
	var base: DPITexture = load(ROOT + path) as DPITexture
	if base != null:
		made = DPITexture.create_from_string(base.get_source(),
			float(size_px) / view_box_of(path))
	_textures[key] = made
	return made


## `texture(KIND_GLYPH, <the glyph's name>, size_px)`.
static func glyph_texture(glyph: Glyphs.Glyph, size_px: int) -> Texture2D:
	return texture(KIND_GLYPH, Glyphs.Glyph.keys()[glyph], size_px)


## Draws the id into `rect` in `colour`; false (and nothing drawn) when there is
## no texture.
static func draw(canvas: CanvasItem, kind: StringName, id: String, rect: Rect2,
		colour: Color) -> bool:
	var tex: Texture2D = texture(kind, id, int(round(minf(rect.size.x, rect.size.y))))
	if tex == null:
		return false
	canvas.draw_texture_rect(tex, rect, false, colour)
	return true


## The author folder of a game-icons path ("game-icons/lorc/wheat.svg" → "lorc"),
## "" otherwise.
static func author_of(path: String) -> String:
	var at: int = path.find(FOLDER_GAME_ICONS)
	if at < 0:
		return ""
	var rest: String = path.substr(at + FOLDER_GAME_ICONS.length())
	var slash: int = rest.find("/")
	return "" if slash <= 0 else rest.substr(0, slash)


## Every path the map can resolve to (files and stand-ins), sorted, for the
## credits and the tools. Whether a file exists is not checked here.
static func all_paths() -> PackedStringArray:
	_ensure_map()
	var seen: Dictionary[String, bool] = {}
	for kind: StringName in KINDS:
		var section: Dictionary = _map.get(String(kind), {})
		for id: Variant in section:
			seen[str(section[id])] = true
	var stand_ins: Dictionary = _map.get(KEY_STAND_INS, {})
	for path: Variant in stand_ins:
		seen[str(stand_ins[path])] = true
	var out: PackedStringArray = PackedStringArray(seen.keys())
	out.sort()
	return out


## The raw sections of the map as read (tests check them against the content).
static func section(kind: StringName) -> Dictionary:
	_ensure_map()
	return _map.get(String(kind), {})


## The stand-in table, custom path → set path.
static func stand_ins() -> Dictionary:
	_ensure_map()
	return _map.get(KEY_STAND_INS, {})


## The side of the square a mapped path's source is drawn on (§4).
static func view_box_of(path: String) -> float:
	if path.begins_with(FOLDER_PHOSPHOR) or path.begins_with(FOLDER_CUSTOM_CHROME):
		return VIEW_BOX_CHROME
	return VIEW_BOX_ILLUSTRATIVE


## Reads another map and clears every cache — tests point it at a fixture, then
## back at MAP_PATH in `after_each`.
static func load_map(path: String) -> void:
	_map_path = path
	_is_loaded = false
	_map = {}
	_textures.clear()
	_ensure_map()


## Reads the atlas from another directory and clears its caches — the atlas test
## builds into `user://` and points here; `ATLAS_DIR` puts it back.
static func load_atlas(dir: String) -> void:
	_atlas_dir = dir
	_is_atlas_read = false
	_atlas_index.clear()
	_atlas_pages.clear()


static func _ensure_map() -> void:
	if _is_loaded:
		return
	_is_loaded = true
	_map = {}
	var file: FileAccess = FileAccess.open(_map_path, FileAccess.READ)
	if file == null:
		push_error("Icons: cannot read %s" % _map_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Icons: %s is not a JSON object" % _map_path)
		return
	var root: Dictionary = parsed
	for key: Variant in root:
		if typeof(root[key]) == TYPE_DICTIONARY:
			_map[str(key)] = root[key]


## §6: the file, else its stand-in, else "".
static func _resolve(path: String) -> String:
	if ResourceLoader.exists(ROOT + path):
		return path
	var stand_in: String = str(stand_ins().get(path, ""))
	if not stand_in.is_empty() and ResourceLoader.exists(ROOT + stand_in):
		return stand_in
	return ""


static func _uses_atlas() -> bool:
	return bool(ProjectSettings.get_setting(ATLAS_SETTING, false))


## An `AtlasTexture` over the nearest built size at least `size_px` (the largest
## when none is), or null when the atlas lacks the path.
static func _atlas_texture(path: String, size_px: int) -> Texture2D:
	_read_atlas()
	var built: int = -1
	for size: int in ATLAS_SIZES:
		if not _atlas_index.has(size):
			continue
		built = size
		if size >= size_px:
			break
	if built < 0:
		return null
	var entry: Array = _atlas_index[built].get(path, [])
	var page: Texture2D = _atlas_page(built)
	if entry.size() != 4 or page == null:
		return null
	var tex: AtlasTexture = AtlasTexture.new()
	tex.atlas = page
	tex.region = Rect2(float(entry[0]), float(entry[1]), float(entry[2]), float(entry[3]))
	return tex


static func _read_atlas() -> void:
	if _is_atlas_read:
		return
	_is_atlas_read = true
	var file: FileAccess = FileAccess.open(_atlas_dir.path_join(ATLAS_INDEX), FileAccess.READ)
	if file == null:
		push_error("Icons: the atlas is switched on but %s has no index" % _atlas_dir)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var root: Dictionary = parsed
	for size_key: Variant in root:
		if typeof(root[size_key]) == TYPE_DICTIONARY:
			_atlas_index[int(str(size_key))] = root[size_key]


## A page is an imported texture when it ships inside the project, a plain
## image when a tool just wrote it (`user://`).
static func _atlas_page(size: int) -> Texture2D:
	if _atlas_pages.has(size):
		return _atlas_pages[size]
	var page_path: String = _atlas_dir.path_join(ATLAS_PAGE % size)
	var page: Texture2D = null
	if ResourceLoader.exists(page_path):
		page = load(page_path) as Texture2D
	elif FileAccess.file_exists(page_path):
		var image: Image = Image.load_from_file(page_path)
		if image != null:
			page = ImageTexture.create_from_image(image)
	_atlas_pages[size] = page
	return page
