extends GutTest
## S6.9 — every achievement can be earned (release.md §13.1): for each def the
## smallest profile and run that satisfy its `when`, built from the grammar, so
## a new def is covered without a new test. Its strings exist in both languages
## with the placeholder §3.3 says, and every id it names exists in the content.

const EVENTS_DIR: String = "res://data/events"
const EFFECT_SET_FLAG: String = "set_flag"


func _book() -> AchievementBook:
	var book: AchievementBook = AchievementBook.load_file()
	assert_eq(book.errors, [] as Array[String])
	return book


func _db() -> ContentDB:
	var result: ContentLoadResult = ContentLoader.load_root("res://data")
	assert_true(result.ok(), result.error_text())
	return result.db


## The smallest [profile, run, totals] that make `def` hold, key by key.
static func _satisfy(def: AchievementDef) -> Array:
	var profile: Dictionary = {}
	var run: Dictionary = {}
	var totals: Dictionary[String, Array] = {}
	for key: String in def.when:
		var value: Variant = def.when[key]
		match key:
			AchievementBook.WHEN_RUNS_COMPLETED:
				profile[AchievementBook.PROFILE_RUNS] = int(value)
			AchievementBook.WHEN_RUNS_WON:
				profile[AchievementBook.PROFILE_WON] = int(value)
			AchievementBook.WHEN_OUTCOMES_WON:
				var by_outcome: Dictionary = {}
				for id: Variant in value:
					by_outcome[str(id)] = 1
				profile[AchievementBook.PROFILE_WINS_BY_OUTCOME] = by_outcome
			AchievementBook.WHEN_ARCHITECTURES_WON:
				var by_architecture: Dictionary = {}
				for id: Variant in value:
					by_architecture[str(id)] = {AchievementBook.PROFILE_ARCH_WINS: 1}
				profile[AchievementBook.PROFILE_BY_ARCHITECTURE] = by_architecture
			AchievementBook.WHEN_ENDINGS_SEEN:
				var endings: Array = []
				for i: int in int(value):
					endings.append("ending_%d" % i)
				profile[AchievementBook.PROFILE_ENDINGS_SEEN] = endings
			AchievementBook.WHEN_CODEX_ALL:
				var codex: Dictionary = {}
				for tab: Variant in value:
					codex[str(tab)] = ["seen"]
					totals[str(tab)] = ["seen"]
				profile[AchievementBook.PROFILE_CODEX] = codex
			AchievementBook.WHEN_WON:
				run[AchievementBook.FACT_WON] = true
			AchievementBook.WHEN_OUTCOME:
				run[AchievementBook.FACT_OUTCOME] = str((value as Array)[0])
			AchievementBook.WHEN_VARIANT:
				run[AchievementBook.FACT_VARIANT] = str((value as Array)[0])
			AchievementBook.WHEN_ARCHITECTURE:
				run[AchievementBook.FACT_ARCHITECTURE] = str((value as Array)[0])
			AchievementBook.WHEN_DIFFICULTY:
				run[AchievementBook.FACT_DIFFICULTY] = str((value as Array)[0])
			AchievementBook.WHEN_SCENARIO:
				run[AchievementBook.FACT_SCENARIO] = str((value as Array)[0])
			AchievementBook.WHEN_DIRECTIVES_MIN:
				var directives: Array = []
				for i: int in int(value):
					directives.append("directive_%d" % i)
				run[AchievementBook.FACT_DIRECTIVES] = directives
			AchievementBook.WHEN_DAYS_MAX:
				run[AchievementBook.FACT_DAYS] = int(value)
			AchievementBook.WHEN_FLAG:
				run[AchievementBook.FACT_FLAGS] = (value as Array).duplicate()
	return [profile, run, totals]


func test_every_def_can_be_earned() -> void:
	var book: AchievementBook = _book()
	for def: AchievementDef in book.defs:
		var parts: Array = _satisfy(def)
		var totals: Dictionary[String, Array] = parts[2]
		var earned: Array[String] = book.newly_earned(parts[0], parts[1], totals)
		assert_true(earned.has(def.id), "%s is earned by its own conditions" % def.id)


func test_a_fresh_profile_earns_nothing() -> void:
	assert_eq(_book().newly_earned({}, {}, {}), [] as Array[String])


func test_every_name_and_detail_exists_in_both_languages() -> void:
	var duplicates: Array[String] = []
	var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
		duplicates)
	var book: AchievementBook = _book()
	for def: AchievementDef in book.defs:
		for key: String in [AchievementDef.name_key(def.id), AchievementDef.detail_key(def.id)]:
			assert_true(table.has(key), key)
			if not table.has(key):
				continue
			assert_false(table[key][StringTable.COLUMN_EN].is_empty(), key + " en")
			assert_false(table[key][StringTable.COLUMN_DE].is_empty(), key + " de")
		var detail: String = AchievementDef.detail_key(def.id)
		if not table.has(detail):
			continue
		# §3.3: a detail may carry the one value `detail_values` gives, never
		# another; both languages carry the same.
		var allowed: PackedStringArray = []
		for name: Variant in book.detail_values(def):
			allowed.append("{%s}" % str(name))
		var en: PackedStringArray = StringTable.placeholders(table[detail][StringTable.COLUMN_EN])
		var de: PackedStringArray = StringTable.placeholders(table[detail][StringTable.COLUMN_DE])
		assert_eq(en, de, detail)
		for placeholder: String in en:
			assert_true(allowed.has(placeholder), "%s: %s" % [detail, placeholder])
		assert_eq(StringTable.placeholders(table[AchievementDef.name_key(def.id)][
			StringTable.COLUMN_EN]), PackedStringArray(), "a name has no placeholder")


func test_every_id_named_exists_in_the_content() -> void:
	var db: ContentDB = _db()
	var book: AchievementBook = _book()
	for def: AchievementDef in book.defs:
		for key: String in def.when:
			var value: Variant = def.when[key]
			if typeof(value) != TYPE_ARRAY:
				continue
			for id: Variant in value:
				var name: String = str(id)
				match key:
					AchievementBook.WHEN_OUTCOMES_WON, AchievementBook.WHEN_OUTCOME:
						assert_true(World.OUTCOME_IDS.has(name), "%s: %s" % [def.id, name])
					AchievementBook.WHEN_ARCHITECTURES_WON, AchievementBook.WHEN_ARCHITECTURE:
						assert_true(db.architecture_by_id.has(name), "%s: %s" % [def.id, name])
					AchievementBook.WHEN_DIFFICULTY:
						assert_true(db.difficulty_by_id.has(name), "%s: %s" % [def.id, name])
					AchievementBook.WHEN_SCENARIO:
						assert_true(db.scenario_by_id.has(name), "%s: %s" % [def.id, name])
					AchievementBook.WHEN_CODEX_ALL:
						assert_true(ProfileManager.CODEX_TABS.has(name), "%s: %s" % [def.id, name])
					AchievementBook.WHEN_VARIANT:
						assert_true(_variants(db).has(name), "%s: %s" % [def.id, name])


func test_every_architecture_has_its_achievement() -> void:
	var db: ContentDB = _db()
	var book: AchievementBook = _book()
	for def: ArchitectureDef in db.architectures:
		assert_not_null(book.find("arch_" + def.id), def.id)


func test_every_flag_is_set_by_some_event() -> void:
	var set_somewhere: Array[String] = []
	for file: String in DirAccess.get_files_at(EVENTS_DIR):
		if file.get_extension() != "json":
			continue
		var json: JSON = JSON.new()
		assert_eq(json.parse(FileAccess.get_file_as_string(EVENTS_DIR.path_join(file))), OK, file)
		_collect_flags(json.data, set_somewhere)
	for flag: String in _book().flag_ids():
		assert_true(set_somewhere.has(flag), "%s is set by an event" % flag)


func test_the_profile_fields_the_book_reads_are_the_profile_s() -> void:
	assert_eq(AchievementBook.PROFILE_RUNS, ProfileManager.KEY_RUNS)
	assert_eq(AchievementBook.PROFILE_WON, ProfileManager.KEY_WON)
	assert_eq(AchievementBook.PROFILE_WINS_BY_OUTCOME, ProfileManager.KEY_WINS_BY_OUTCOME)
	assert_eq(AchievementBook.PROFILE_BY_ARCHITECTURE, ProfileManager.KEY_BY_ARCHITECTURE)
	assert_eq(AchievementBook.PROFILE_ARCH_WINS, ProfileManager.ARCH_WINS)
	assert_eq(AchievementBook.PROFILE_ENDINGS_SEEN, ProfileManager.KEY_ENDINGS_SEEN)
	assert_eq(AchievementBook.PROFILE_CODEX, ProfileManager.KEY_CODEX)
	for stat: String in AchievementBook.STAT_NAMES:
		assert_true(ProfileManager.to_dict().has(stat), stat)


func test_api_names() -> void:
	assert_eq(PlatformService.achievement_api_name("first_run"), "ACH_FIRST_RUN")
	assert_eq(PlatformService.stat_api_name("runs_won"), "STAT_RUNS_WON")


## Every ending variant id the content knows.
static func _variants(db: ContentDB) -> Array[String]:
	var out: Array[String] = []
	for ending: EndingDef in db.endings.values():
		for line: EndingLineDef in ending.variants:
			out.append(line.id)
	return out


## `set_flag` effects' `flag`, and an option's `flags` list.
static func _collect_flags(node: Variant, into: Array[String]) -> void:
	if typeof(node) == TYPE_ARRAY:
		for item: Variant in node:
			_collect_flags(item, into)
	elif typeof(node) == TYPE_DICTIONARY:
		var d: Dictionary = node
		if str(d.get("effect", "")) == EFFECT_SET_FLAG and typeof(d.get("flag")) == TYPE_STRING:
			into.append(str(d["flag"]))
		if typeof(d.get("flags")) == TYPE_ARRAY:
			for flag: Variant in d["flags"]:
				into.append(str(flag))
		for value: Variant in d.values():
			_collect_flags(value, into)
