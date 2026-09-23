extends GutTest
## S4.1 — `assets.json` and the `asset` scope (`docs/specs/loop-mechanics.md`
## §6). The four kinds are a closed vocabulary, and a kind's modifiers are
## scoped by the loader rather than by the file.

const ASSETS: String = "assets.json"


## The loaded fixture assets, which every content test starts from.
func _db() -> ContentDB:
	return Fixtures.db()


func _asset(content: Dictionary, index: int) -> Dictionary:
	var file: Dictionary = content["assets"]
	var list: Array = file[AssetDef.ROOT_KEY]
	return list[index]


## Loads `content` and asserts that the first error is in `assets.json` at
## `path` and says `fragment`.
func _expect(content: Dictionary, path: String, fragment: String) -> void:
	var result: ContentLoadResult = Fixtures.load_raw(content)
	assert_false(result.ok(), "expected an error at %s" % path)
	var found: bool = false
	for error: ValidationError in result.errors:
		if error.file.ends_with(ASSETS) and error.path == path \
				and error.message.to_lower().contains(fragment.to_lower()):
			found = true
	assert_true(found, "no \"%s\" at %s in:\n%s" % [fragment, path, result.error_text()])


func test_the_four_kinds_load_in_their_own_order() -> void:
	var db: ContentDB = _db()
	assert_eq(db.assets.size(), AssetDef.KINDS.size())
	var order: Array[String] = []
	for kind: String in db.assets:
		order.append(kind)
	assert_eq(order, AssetDef.KINDS, "the file's order never decides")
	assert_eq(db.asset("fleet").glyph, "ASSET_FLEET")
	assert_eq(db.asset("fleet").watched_by, ["public_sentiment"] as Array[String])
	assert_null(db.asset("nothing"))


func test_every_modifier_is_scoped_to_its_kind() -> void:
	for kind: String in AssetDef.KINDS:
		for modifier: ModifierDef in _db().asset(kind).modifiers:
			assert_eq(modifier.scope_kind, ModifierDef.ScopeKind.ASSET, kind)
			assert_eq(modifier.scope_asset, kind)
			assert_eq(modifier.scope_min, 1, "one of them standing there is enough")


func test_a_fifth_kind_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var file: Dictionary = content["assets"]
	var list: Array = file[AssetDef.ROOT_KEY]
	list.append({"kind": "drone", "glyph": "ASSET_FLEET", "modifiers": []})
	_expect(content, "%s[4].kind" % AssetDef.ROOT_KEY, "unknown asset kind")


func test_a_missing_kind_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var file: Dictionary = content["assets"]
	var list: Array = file[AssetDef.ROOT_KEY]
	list.remove_at(3)
	_expect(content, AssetDef.ROOT_KEY, "missing asset kind")


func test_a_duplicate_kind_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var file: Dictionary = content["assets"]
	var list: Array = file[AssetDef.ROOT_KEY]
	list.append((list[0] as Dictionary).duplicate(true))
	_expect(content, "%s[4].kind" % AssetDef.ROOT_KEY, "duplicate")


func test_a_scope_in_the_file_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var modifiers: Array = _asset(content, 0)["modifiers"]
	(modifiers[0] as Dictionary)["scope"] = {"attr": "industry", "min": 2}
	_expect(content, "%s[0].modifiers[0].scope" % AssetDef.ROOT_KEY, "scoped to its kind")


func test_a_global_target_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var modifiers: Array = _asset(content, 0)["modifiers"]
	(modifiers[0] as Dictionary)["target"] = "footprint"
	_expect(content, "%s[0].modifiers[0].target" % AssetDef.ROOT_KEY, "global")


func test_an_unknown_glyph_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	_asset(content, 0)["glyph"] = "ASSET_BALLOON"
	_expect(content, "%s[0].glyph" % AssetDef.ROOT_KEY, "unknown glyph")


func test_the_wrong_version_is_rejected() -> void:
	var content: Dictionary = Fixtures.raw_content()
	var file: Dictionary = content["assets"]
	file["version"] = 2
	_expect(content, "version", "outside")


func test_the_content_hash_changes_with_an_asset_value() -> void:
	var before: String = Fixtures.load_raw(Fixtures.raw_content()).db.content_hash
	var content: Dictionary = Fixtures.raw_content()
	var modifiers: Array = _asset(content, 0)["modifiers"]
	(modifiers[0] as Dictionary)["value"] = 2.0
	var after: ContentLoadResult = Fixtures.load_raw(content)
	assert_true(after.ok(), after.error_text())
	assert_ne(after.db.content_hash, before)
