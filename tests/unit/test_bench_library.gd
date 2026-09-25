extends GutTest
## S6.13 — `BenchLibrary` (docs/specs/benchmark.md §12.1): the entries the game
## lists, read as data from three folders. A file that does not read is skipped
## and counted; the repository's folder is read only when asked.

const ROOT: String = "user://test_bench_library_unit"
const CANARY: String = "res://tests/fixtures/bench/determinism_entry.json"

var _showcase: String = ""
var _user: String = ""
var _dev: String = ""
var _saved: Array[String] = []


func before_each() -> void:
	_saved = [BenchLibrary.showcase_dir, BenchLibrary.user_dir, BenchLibrary.dev_dir]
	Fixtures.remove_root(ROOT)
	_showcase = ROOT.path_join("showcase")
	_user = ROOT.path_join("user")
	_dev = ROOT.path_join("dev")
	for dir: String in [_showcase, _user, _dev]:
		DirAccess.make_dir_recursive_absolute(dir)
	BenchLibrary.showcase_dir = _showcase
	BenchLibrary.user_dir = _user
	BenchLibrary.dev_dir = _dev


func after_each() -> void:
	BenchLibrary.showcase_dir = _saved[0]
	BenchLibrary.user_dir = _saved[1]
	BenchLibrary.dev_dir = _saved[2]
	Fixtures.remove_root(ROOT)


func _write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _good(dir: String, file_name: String = "good.json") -> void:
	_write(dir.path_join(file_name), FileAccess.get_file_as_bytes(CANARY))


func test_one_good_one_broken_one_oversized_gives_one_entry_and_two_skipped() -> void:
	_good(_user)
	_write(_user.path_join("broken.json"), "{ not an entry".to_utf8_buffer())
	var big: PackedByteArray = PackedByteArray()
	big.resize(BenchLibrary.MAX_BYTES + 1)
	big.fill(" ".unicode_at(0))
	_write(_user.path_join("huge.json"), big)
	var library: BenchLibrary = BenchLibrary.scan(false)
	assert_eq(library.entries.size(), 1)
	assert_eq(library.skipped, 2)
	assert_eq(library.paths, [_user.path_join("good.json")] as Array[String])
	assert_eq(library.entries[0].seed_value, 1001)


func test_the_dev_folder_is_read_only_when_asked() -> void:
	_good(_dev)
	assert_eq(BenchLibrary.scan(false).entries.size(), 0, "a release build's list")
	assert_eq(BenchLibrary.scan(true).entries.size(), 1, "a debug build's")


func test_the_showcase_comes_first_and_other_files_are_ignored() -> void:
	_good(_user, "a.json")
	_good(_showcase, "b.json")
	_write(_user.path_join("notes.txt"), "not a run".to_utf8_buffer())
	var library: BenchLibrary = BenchLibrary.scan(false)
	assert_eq(library.entries.size(), 2)
	assert_eq(library.paths[0], _showcase.path_join("b.json"))
	assert_eq(library.skipped, 0, "a file of another kind is not a skipped entry")


func test_missing_folders_are_empty() -> void:
	Fixtures.remove_root(ROOT)
	var library: BenchLibrary = BenchLibrary.scan(true)
	assert_eq(library.entries.size(), 0)
	assert_eq(library.skipped, 0)
