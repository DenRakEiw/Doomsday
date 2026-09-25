extends GutTest
## S6.3 — the picture slot's hooks for D6.10 (`docs/specs/illustrations.md` §8.1):
## mipmaps sampled, 4 : 3 kept in compact, a width for the full layout.

const FIXTURE_ROOT: String = "res://tests/fixtures/illustrations"
const FIXTURE_ID: String = "end_ascendance"


func _slot() -> IllustrationSlot:
	var slot: IllustrationSlot = IllustrationSlot.new()
	add_child_autofree(slot)
	return slot


func test_texture_filter_samples_mipmaps() -> void:
	var slot: IllustrationSlot = _slot()
	slot.root = FIXTURE_ROOT
	slot.show_illustration(FIXTURE_ID, Glyphs.Glyph.OUTCOME)
	assert_true(slot.has_picture())
	var pictures: Array[Node] = slot.find_children("*", "TextureRect", false, false)
	assert_eq(pictures.size(), 1)
	assert_eq((pictures[0] as TextureRect).texture_filter,
		CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)


func test_compact_height_follows_width_at_four_to_three() -> void:
	var slot: IllustrationSlot = _slot()
	slot.compact = true
	slot.size = Vector2(840.0, 10.0)
	assert_almost_eq(slot.custom_minimum_size.y, 630.0, 0.01)
	slot.size = Vector2(368.0, 10.0)
	assert_almost_eq(slot.custom_minimum_size.y, 276.0, 0.01, "and again when it narrows")
	assert_eq(slot.custom_minimum_size.x, 0.0, "the column gives the width")


func test_width_sets_full_layout_size() -> void:
	var slot: IllustrationSlot = _slot()
	assert_eq(slot.custom_minimum_size, Vector2(280.0, 210.0), "a card's slot by default")
	slot.width = 420.0
	assert_eq(slot.custom_minimum_size, Vector2(420.0, 315.0))


func test_has_file_needs_the_file() -> void:
	var slot: IllustrationSlot = _slot()
	slot.root = FIXTURE_ROOT
	assert_true(slot.has_file(FIXTURE_ID))
	assert_false(slot.has_file("end_merge"))
	assert_false(slot.has_file(""))


## icons.md §7: a counter-move without a picture shows its icon file at
## `ICON_HERO` instead of the faction's glyph; a picture still wins.
func test_counter_move_shows_its_icon_without_a_picture() -> void:
	var slot: IllustrationSlot = _slot()
	slot.show_illustration("", Glyphs.Glyph.FACTION_GOVERNMENTS, &"TEXT_2",
		Icons.KIND_COUNTER_MOVE, "cm_lockdown")
	assert_true(slot.fallback_icon().visible)
	assert_false(slot.fallback_glyph().visible)
	assert_eq(slot.fallback_icon().box_size, float(UiTokens.ICON_HERO))
	slot.show_illustration("", Glyphs.Glyph.FACTION_GOVERNMENTS, &"TEXT_2",
		Icons.KIND_COUNTER_MOVE, "no_such_move")
	assert_false(slot.fallback_icon().visible, "no file: the faction glyph again")
	assert_true(slot.fallback_glyph().visible)
	slot.root = FIXTURE_ROOT
	slot.show_illustration(FIXTURE_ID, Glyphs.Glyph.OUTCOME, &"TEXT_2",
		Icons.KIND_COUNTER_MOVE, "cm_lockdown")
	assert_true(slot.has_picture())
	assert_false(slot.fallback_icon().visible, "a picture wins over the icon")
