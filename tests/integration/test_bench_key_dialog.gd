extends GutTest
## S6.12g — the OpenRouter key dialog (docs/specs/benchmark.md §19.6–§19.7):
## *Save* hands the key to the store (a fake here), the captions name its last
## four characters and never more, a store that refuses keeps it for the session,
## *Remove* forgets it, the field is emptied when the dialog closes, and *Check*
## reads OpenRouter's answer — valid, with a limit, refused, unreachable — from a
## stand-in. Key calls run inline (`BenchJobs.key_inline`); nothing touches the
## real store or the network.

const DIALOG: PackedScene = preload("res://ui/modals/bench_key.tscn")
const KEY: String = "sk-or-v1-abcdefghijklmnop"
const OTHER_KEY: String = "not-an-openrouter-key-9876"

var _dialog: Control = null
var _saved: Dictionary = {}
var _store: Dictionary = {}
var _store_refuses: bool = false
var _answer: Dictionary = {}
var _asked: Array[String] = []


func before_each() -> void:
	_saved = {
		"store": BenchJobs.key_store, "session": BenchJobs.session_key,
		"status": BenchJobs.key_status, "hint": BenchJobs.key_hint,
		"inline": BenchJobs.key_inline, "http": BenchJobs.key_http,
	}
	_store.clear()
	_store_refuses = false
	_asked.clear()
	_answer = {BenchJobs.FIELD_STATUS: 200, BenchJobs.FIELD_BODY: ""}
	var store: BenchKeyStore = BenchKeyStore.new()
	store.backend_override = _fake_store
	BenchJobs.key_store = store
	BenchJobs.session_key = ""
	BenchJobs.key_status = BenchJobs.KEY_UNKNOWN
	BenchJobs.key_hint = ""
	BenchJobs.key_inline = true
	BenchJobs.key_http = func(key: String) -> Dictionary:
		_asked.append(key)
		return _answer
	_dialog = DIALOG.instantiate() as Control
	add_child_autofree(_dialog)
	_dialog.call(&"open")


func after_each() -> void:
	BenchJobs.key_store = _saved["store"]
	BenchJobs.session_key = _saved["session"]
	BenchJobs.key_status = _saved["status"]
	BenchJobs.key_hint = _saved["hint"]
	BenchJobs.key_inline = _saved["inline"]
	BenchJobs.key_http = _saved["http"]


func _fake_store(op: String, key: String) -> Dictionary:
	match op:
		BenchKeyStore.OP_SAVE:
			if _store_refuses:
				return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_ERROR}
			_store["key"] = key
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK}
		BenchKeyStore.OP_REMOVE:
			_store.erase("key")
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK}
	if _store.has("key"):
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK,
			BenchKeyStore.FIELD_KEY: _store["key"]}
	return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_NONE}


func _field() -> LineEdit:
	return _dialog.call(&"field")


func _save(key: String) -> void:
	_field().text = key
	(_dialog.call(&"save_button") as ConsoleButton).pressed.emit()


## Every label and accessible name in the dialog, to prove the key is in none.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	if node is Control:
		out.append((node as Control).accessibility_name)
		out.append((node as Control).tooltip_text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


func test_opening_with_nothing_stored_says_not_set() -> void:
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_NONE)
	assert_eq(_dialog.call(&"state_text"), tr("UI_KEY_STATE_NONE"))


func test_save_hands_the_key_to_the_store() -> void:
	_save(KEY)
	assert_eq(_store.get("key", ""), KEY)
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_STORED)
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_SAVED"))


func test_save_trims_spaces_and_line_breaks() -> void:
	_save("  " + KEY + "\r\n")
	assert_eq(_store.get("key", ""), KEY)


func test_empty_field_saves_nothing() -> void:
	_save("   ")
	assert_false(_store.has("key"))
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_NONE)


func test_hint_shows_the_last_four_characters_only() -> void:
	_save(KEY)
	var state: String = str(_dialog.call(&"state_text"))
	assert_string_contains(state, "…" + KEY.right(4))
	assert_false(state.contains(KEY.right(5)), "no fifth character")
	for text: String in _texts(_dialog):
		assert_false(text.contains(KEY), "the key is in no label or name")


func test_saved_key_leaves_the_field() -> void:
	_save(KEY)
	assert_eq(_field().text, "")


func test_field_is_cleared_when_the_dialog_closes() -> void:
	_field().text = KEY
	_dialog.visible = false
	assert_eq(_field().text, "")
	assert_true(_field().secret, "hidden again")


func test_show_turns_the_field_readable() -> void:
	assert_true(_field().secret)
	(_dialog.call(&"show_button") as ConsoleButton).button_pressed = true
	assert_false(_field().secret)


func test_key_that_is_not_openrouters_warns_and_saves() -> void:
	_save(OTHER_KEY)
	assert_eq(_store.get("key", ""), OTHER_KEY)
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_FORMAT"))


func test_store_that_refuses_keeps_the_key_for_the_session() -> void:
	_store_refuses = true
	_save(KEY)
	assert_eq(BenchJobs.session_key, KEY)
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_SESSION)
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_STORE_FAILED"))
	assert_string_contains(str(_dialog.call(&"state_text")), "…" + KEY.right(4))


func test_remove_forgets_store_and_session() -> void:
	_save(KEY)
	BenchJobs.session_key = OTHER_KEY
	(_dialog.call(&"remove_button") as ConsoleButton).pressed.emit()
	assert_false(_store.has("key"))
	assert_eq(BenchJobs.session_key, "")
	assert_eq(BenchJobs.key_status, BenchJobs.KEY_NONE)
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_REMOVED"))


func test_check_without_a_typed_key_asks_about_the_saved_one() -> void:
	_save(KEY)
	_answer = {BenchJobs.FIELD_STATUS: 200,
		BenchJobs.FIELD_BODY: JSON.stringify({"data": {"usage": 1.5, "limit": null}})}
	(_dialog.call(&"check_button") as ConsoleButton).pressed.emit()
	assert_eq(_asked, [KEY] as Array[String])
	assert_eq(_dialog.call(&"result_text"),
		tr("UI_KEY_VALID").format({"usage": Format.decimal(1.5, 2)}))


func test_check_names_the_limit_when_the_key_has_one() -> void:
	_answer = {BenchJobs.FIELD_STATUS: 200,
		BenchJobs.FIELD_BODY: JSON.stringify({"data": {"usage": 0.25, "limit": 10}})}
	_field().text = KEY
	(_dialog.call(&"check_button") as ConsoleButton).pressed.emit()
	assert_eq(_asked, [KEY] as Array[String])
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_VALID_LIMIT").format({
		"usage": Format.decimal(0.25, 2), "limit": Format.decimal(10.0, 2)}))


func test_check_of_a_refused_key_says_invalid() -> void:
	_answer = {BenchJobs.FIELD_STATUS: 401, BenchJobs.FIELD_BODY: ""}
	_field().text = KEY
	(_dialog.call(&"check_button") as ConsoleButton).pressed.emit()
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_INVALID"))


func test_check_without_an_answer_says_offline() -> void:
	_answer = {BenchJobs.FIELD_STATUS: -1, BenchJobs.FIELD_BODY: ""}
	_field().text = KEY
	(_dialog.call(&"check_button") as ConsoleButton).pressed.emit()
	assert_eq(_dialog.call(&"result_text"), tr("UI_KEY_OFFLINE"))


func test_settings_row_shows_the_same_hint() -> void:
	_save(KEY)
	assert_eq(BenchJobs.key_state_text(),
		tr("UI_KEY_STATE_STORED").format({"hint": "…" + KEY.right(4)}))
