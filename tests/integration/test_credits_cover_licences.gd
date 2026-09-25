extends GutTest
## S6.3 — the credits against `docs/ASSET_LICENCES.md` (`docs/specs/icons.md`
## §11.4): every shipped asset that is not own work is credited, and nothing is
## credited that is not recorded.
##
## A table of shipped assets is one whose first header cell is `Id`. The credits'
## side is the entries that show — an entry whose file does not ship yet (the
## icon sets before S6.4) credits nothing, so its row may still be missing.

const LICENCES_PATH: String = "res://docs/ASSET_LICENCES.md"
const HEADER_ID: String = "Id"
const LICENCE_COLUMN: String = "licence"
const OWN_WORK: String = "own work"

var _data: Dictionary = {}


func before_all() -> void:
	_data = CreditsData.load_file()[CreditsData.KEY_DATA]


## Every table in the file: its header cells, then its rows' cells.
static func _tables(text: String) -> Array[Array]:
	var tables: Array[Array] = []
	var current: Array[PackedStringArray] = []
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("|"):
			if not current.is_empty():
				tables.append(current)
				current = []
			continue
		var cells: PackedStringArray = []
		for cell: String in line.trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(cell.strip_edges())
		# The row under the header is only dashes.
		if cells[0].begins_with("---"):
			continue
		current.append(cells)
	if not current.is_empty():
		tables.append(current)
	return tables


## Shipped id → whether it is own work. An id met twice goes to `duplicates`.
static func _shipped_rows(duplicates: Array[String] = []) -> Dictionary[String, bool]:
	var rows: Dictionary[String, bool] = {}
	for table: Array in _tables(FileAccess.get_file_as_string(LICENCES_PATH)):
		var header: PackedStringArray = table[0]
		if header[0] != HEADER_ID:
			continue
		var licence_at: int = -1
		for i: int in header.size():
			if licence_at < 0 and header[i].to_lower().contains(LICENCE_COLUMN):
				licence_at = i
		for r: int in range(1, table.size()):
			var cells: PackedStringArray = table[r]
			var id: String = cells[0].replace("`", "")
			var own: bool = licence_at >= 0 and licence_at < cells.size() \
				and cells[licence_at].to_lower().contains(OWN_WORK)
			if rows.has(id):
				duplicates.append(id)
			rows[id] = own
	return rows


func test_the_licence_file_has_shipped_tables() -> void:
	var rows: Dictionary[String, bool] = _shipped_rows()
	assert_true(rows.has("godot"))
	assert_true(rows.has("font_jetbrains_mono"))
	assert_true(rows["icons_custom"], "own work is recognised")


func test_no_row_id_appears_twice() -> void:
	var duplicates: Array[String] = []
	_shipped_rows(duplicates)
	assert_eq(duplicates, [] as Array[String])


func test_every_shipped_row_is_credited() -> void:
	var credited: Array[String] = CreditsData.credited_rows(_data)
	var rows: Dictionary[String, bool] = _shipped_rows()
	for id: String in rows:
		if not rows[id]:
			assert_has(credited, id, "%s ships without a credits entry" % id)


func test_no_entry_credits_a_missing_row() -> void:
	var rows: Dictionary[String, bool] = _shipped_rows()
	var seen: Dictionary[String, bool] = {}
	for id: String in CreditsData.credited_rows(_data):
		assert_true(rows.has(id), "%s is credited but has no ASSET_LICENCES.md row" % id)
		assert_false(rows.get(id, false), "%s is own work and needs no credit" % id)
		assert_false(seen.has(id), "%s is credited twice" % id)
		seen[id] = true


## §11.5: before S6.4 no game-icon ships, and this passes vacuously.
func test_every_used_author_is_listed() -> void:
	var authors: Dictionary = _data["authors"]
	var used: Dictionary[String, Array] = CreditsData.icons_by_author(
		CreditsData.used_icon_paths())
	for folder: String in used:
		assert_true(authors.has(folder), "game-icons author %s is not in credits.json" % folder)
	pass_test("every author that ships is listed")
