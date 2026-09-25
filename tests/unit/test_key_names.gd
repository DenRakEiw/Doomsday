extends GutTest
## S6.8 — an action's key as text, and the placeholders every text that names a
## key is formatted with (accessibility.md §5.3).

var _keys: Dictionary[String, int] = {}
var _locale: String = ""


func before_each() -> void:
	_keys = Settings.keys.duplicate()
	_locale = TranslationServer.get_locale()
	KeyBindings.reset()


func after_each() -> void:
	TranslationServer.set_locale(_locale)
	Settings.set_keys(_keys)
	KeyBindings.apply_all()


func test_space_is_a_word_in_both_languages() -> void:
	TranslationServer.set_locale("en")
	assert_eq(KeyNames.label(&"game_pause"), "Space")
	TranslationServer.set_locale("de")
	assert_eq(KeyNames.label(&"game_pause"), "Leertaste")


func test_a_letter_key_is_its_letter() -> void:
	assert_eq(KeyNames.label(&"game_tree"), "T")


func test_args_name_all_twelve_keys() -> void:
	var args: Dictionary = KeyNames.args()
	assert_eq(args.size(), 12)
	for placeholder: Variant in args:
		assert_false(str(args[placeholder]).is_empty(), str(placeholder))


func test_after_assign_the_arg_changes() -> void:
	KeyBindings.assign(&"game_tree", KEY_Y)
	assert_eq(str(KeyNames.args()["key_tree"]), "Y")


func test_a_text_without_placeholders_is_unchanged() -> void:
	assert_eq(KeyNames.format("plain {name}"), "plain {name}")
	assert_eq(KeyNames.format("open ({key_tree})"), "open (T)")
