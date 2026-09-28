extends GutTest
## S6.12f — the key store (docs/specs/benchmark.md §19.2) behind its test seam:
## save, load and remove against a fake, the session fallback, where it exists,
## and that the key never becomes an argument of a process. The real store is
## never touched here; the build checked it by hand (PROGRESS).

const KEY: String = "sk-or-v1-0123456789abcdef"

var _stored: Dictionary[String, String] = {}
var _refuse: bool = false
var _calls: Array[String] = []


func before_each() -> void:
	_stored.clear()
	_refuse = false
	_calls.clear()


func _fake(op: String, key: String) -> Dictionary:
	_calls.append(op)
	if _refuse:
		return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_ERROR}
	match op:
		BenchKeyStore.OP_SAVE:
			_stored["key"] = key
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK}
		BenchKeyStore.OP_LOAD:
			if not _stored.has("key"):
				return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_NONE}
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK,
				BenchKeyStore.FIELD_KEY: _stored["key"]}
		BenchKeyStore.OP_REMOVE:
			var had: bool = _stored.erase("key")
			return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_OK if had
				else BenchKeyStore.STATUS_NONE}
	return {BenchKeyStore.FIELD_STATUS: BenchKeyStore.STATUS_ERROR}


func _store() -> BenchKeyStore:
	var store: BenchKeyStore = BenchKeyStore.new()
	store.backend_override = _fake
	return store


func test_a_saved_key_loads_back_and_is_gone_after_remove() -> void:
	var store: BenchKeyStore = _store()
	assert_eq(store.load(), "", "nothing stored yet")
	assert_true(store.save(KEY))
	assert_eq(store.load(), KEY)
	assert_true(store.remove())
	assert_eq(store.load(), "")
	assert_true(store.remove(), "removing nothing leaves nothing stored")


func test_an_empty_key_is_never_handed_to_the_store() -> void:
	var store: BenchKeyStore = _store()
	assert_false(store.save(""))
	assert_eq(_calls, [] as Array[String])


func test_a_store_that_refuses_leaves_the_key_for_the_session() -> void:
	var store: BenchKeyStore = _store()
	assert_ne(store.kind(), BenchKeyStore.KIND_SESSION, "a working store before the refusal")
	_refuse = true
	assert_false(store.save(KEY))
	assert_eq(store.kind(), BenchKeyStore.KIND_SESSION)
	assert_eq(store.load(), "", "a failing store loads nothing")


func test_it_exists_on_windows_and_linux_desktops_only() -> void:
	assert_true(BenchKeyStore.supported_on(true, false, "Windows"))
	assert_true(BenchKeyStore.supported_on(true, false, "Linux"))
	assert_false(BenchKeyStore.supported_on(true, false, "macOS"), "no store for macOS yet")
	assert_false(BenchKeyStore.supported_on(true, true, "Windows"), "not in a browser")
	assert_false(BenchKeyStore.supported_on(false, false, "Android"), "not on a phone")
	assert_false(BenchKeyStore.supported_on(false, false, "iOS"))


func test_the_windows_script_reads_the_key_from_stdin_never_from_its_arguments() -> void:
	var script: String = BenchKeyStore.WINDOWS_SCRIPT
	assert_string_contains(script, "[Console]::In.ReadLine()")
	assert_false(script.contains("$args"), "the script takes no arguments")
	assert_false(script.contains("$env:"), "nor an environment variable")
	for op: String in [BenchKeyStore.OP_SAVE, BenchKeyStore.OP_LOAD, BenchKeyStore.OP_REMOVE]:
		var arguments: PackedStringArray = BenchKeyStore.windows_arguments(op)
		var encoded: String = arguments[arguments.size() - 1]
		var decoded: String = Marshalls.base64_to_raw(encoded).get_string_from_utf16()
		assert_string_contains(decoded, "$op = '%s'" % op)
		assert_string_contains(decoded, BenchKeyStore.WINDOWS_TARGET)
		for argument: String in arguments:
			assert_false(argument.contains(KEY))


func test_the_linux_calls_name_the_attributes_and_never_the_key() -> void:
	var save: PackedStringArray = BenchKeyStore.linux_arguments(BenchKeyStore.OP_SAVE)
	assert_eq(save[0], "store")
	assert_eq(Array(save.slice(2)), Array(PackedStringArray(BenchKeyStore.LINUX_ATTRIBUTES)))
	assert_eq(BenchKeyStore.linux_arguments(BenchKeyStore.OP_LOAD)[0], "lookup")
	assert_eq(BenchKeyStore.linux_arguments(BenchKeyStore.OP_REMOVE)[0], "clear")
