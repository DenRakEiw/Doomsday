extends SceneTree
## Builds the PNG icon atlas (docs/specs/icons.md §10.2, VISUALS q5).
##
##   "$GODOT" --headless --path . -s tools/build_icon_atlas.gd -- [--out=<dir>]
##
## For every file `Icons.all_paths()` resolves to and every size of
## `Icons.ATLAS_SIZES`, the SVG is rasterised at twice the size (the fallback
## cannot follow the viewport's oversampling, so it carries enough for a 2×
## screen) and packed row by row into `icons_<size>.png`; `atlas.json` holds
## `{ "<size>": { "<path>": [x, y, w, h] } }`. The atlas is a build product: not
## committed, and shipped only when `doomsday/icons/use_atlas` is on for an
## export. `tests/unit/test_icons.gd` builds it into `user://` to prove it works.

const ARG_OUT: String = "--out="
const PAGE_WIDTH: int = 2048
## The fallback's resolution over the logical size.
const OVERSAMPLE: float = 2.0
## Between two packed icons, so linear filtering never bleeds a neighbour in.
const PADDING: int = 2


func _init() -> void:
	var out: String = Icons.ATLAS_DIR
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG_OUT):
			out = arg.substr(ARG_OUT.length())
	var result: Dictionary = build(out)
	if not str(result["error"]).is_empty():
		printerr("build_icon_atlas: %s" % result["error"])
		quit(1)
		return
	print("build_icon_atlas: %d icons × %d sizes into %s" % [int(result["icons"]),
		Icons.ATLAS_SIZES.size(), out])
	quit(0)


## Writes the pages and the index into `out`. Returns `{error, icons}`; `error`
## is "" on success.
static func build(out: String) -> Dictionary:
	var sources: Dictionary[String, String] = {}
	for path: String in Icons.all_paths():
		var base: DPITexture = null
		if ResourceLoader.exists(Icons.ROOT + path):
			base = load(Icons.ROOT + path) as DPITexture
		if base != null:
			sources[path] = base.get_source()
	if sources.is_empty():
		return {"error": "no icon file resolves", "icons": 0}
	var made: Error = DirAccess.make_dir_recursive_absolute(out)
	if made != OK:
		return {"error": "cannot create %s (%s)" % [out, error_string(made)], "icons": 0}
	var paths: Array[String] = []
	paths.assign(sources.keys())
	paths.sort()
	var index: Dictionary[String, Dictionary] = {}
	for size: int in Icons.ATLAS_SIZES:
		var packed: Dictionary = _pack(paths, sources, size)
		if not str(packed["error"]).is_empty():
			return {"error": packed["error"], "icons": 0}
		var page: Image = packed["image"]
		var page_path: String = out.path_join(Icons.ATLAS_PAGE % size)
		var saved: Error = page.save_png(page_path)
		if saved != OK:
			return {"error": "cannot write %s (%s)" % [page_path, error_string(saved)],
				"icons": 0}
		index[str(size)] = packed["regions"]
	var file: FileAccess = FileAccess.open(out.path_join(Icons.ATLAS_INDEX), FileAccess.WRITE)
	if file == null:
		return {"error": "cannot write the index into %s" % out, "icons": 0}
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
	return {"error": "", "icons": paths.size()}


## One page: every icon at `size`, left to right, a new row when the page is full.
static func _pack(paths: Array[String], sources: Dictionary[String, String],
		size: int) -> Dictionary:
	var images: Array[Image] = []
	for path: String in paths:
		var image: Image = Image.new()
		var scale: float = OVERSAMPLE * float(size) / Icons.view_box_of(path)
		var loaded: Error = image.load_svg_from_string(sources[path], scale)
		if loaded != OK:
			return {"error": "%s does not rasterise (%s)" % [path, error_string(loaded)]}
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	var cell: int = int(ceil(OVERSAMPLE * float(size))) + PADDING
	var per_row: int = maxi(1, PAGE_WIDTH / cell)
	var rows: int = int(ceil(float(images.size()) / float(per_row)))
	var page: Image = Image.create_empty(PAGE_WIDTH, maxi(1, rows * cell), false,
		Image.FORMAT_RGBA8)
	var regions: Dictionary[String, Array] = {}
	for i: int in images.size():
		var image: Image = images[i]
		var at: Vector2i = Vector2i((i % per_row) * cell, (i / per_row) * cell)
		page.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)
		regions[paths[i]] = [at.x, at.y, image.get_width(), image.get_height()]
	return {"error": "", "image": page, "regions": regions}
