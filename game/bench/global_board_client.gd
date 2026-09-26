class_name GlobalBoardClient
extends Node
## The game's one network access (docs/specs/benchmark.md §0 item 6, §16.6): the
## public leaderboard, fetched when the player opens the benchmark list, and one
## run's file when they watch it. Plain GETs of public files — nothing is sent,
## nothing identifies the player.
##
## A board is shown at once from the cache or the build's copy, whichever is
## newer; a fetch that works replaces it and is cached, one that fails leaves
## it. A downloaded run is used only when its SHA-256 is the one the verifier
## checked. Files are data: JSON through `GlobalBoard.parse` and
## `BenchEntry.from_bytes`, never a resource.
##
## The response handlers are public so the tests can feed them made-up results
## without a network.

signal board_changed(board: GlobalBoard, source: String, loading: bool)
## `entry` is null exactly when `reason` is one of the `FAIL_*`.
signal run_ready(entry: BenchEntry, reason: String)

const SOURCE_ONLINE: String = "online"
const SOURCE_CACHE: String = "cache"
const SOURCE_SHIPPED: String = "shipped"
const SOURCE_NONE: String = "none"
const FAIL_OFFLINE: String = "offline"
const FAIL_CHANGED: String = "changed"
const FAIL_UNREADABLE: String = "unreadable"
const FAIL_OFF: String = "off"
## web.md §7.1: the folder under `UserPaths.root()`.
const CACHE_FOLDER: String = "benchmark/online/"
const SHIPPED_PATH: String = "res://benchmark/global/leaderboard.json"
const BOARD_FILE: String = "leaderboard.json"
const RUNS_DIR: String = "runs"
const TMP_SUFFIX: String = ".tmp"
const STATUS_OK: int = 200
const MS_PER_SECOND: int = 1000

## Every fetch started — a GET, or a read of the debug board that stands in for
## one (the tests' ear).
var requests_made: int = 0
## The addresses and limits (`data/benchmark.json` `global`); read in `_ready`
## when nobody set it.
var config: BenchConfig = null
## Where a new client caches; the suite points it at a folder of its own
## (`tests/support/pre_run.gd`), so no test reads or writes the player's cache.
static var default_cache_dir: String = UserPaths.at(CACHE_FOLDER)

## Where the board and the runs are cached.
var cache_dir: String = default_cache_dir
var shipped_path: String = SHIPPED_PATH
## Debug builds' `--global-board=<path>` (§16.9): a board file on disk in place
## of the network, its runs next to it under `runs/`.
var local_board_path: String = ""
## A test's clock for the refetch window; below zero, the real one.
var clock_override_ms: int = -1

## What the last successful fetch in this process brought, and when: reopening
## the list within `min_refetch_s` reuses it (§16.6).
static var _fetched_text: String = ""
static var _fetched_at_ms: int = -1

var _board_request: HTTPRequest = null
var _run_request: HTTPRequest = null
var _local: GlobalBoard = null
var _local_source: String = SOURCE_NONE
var _pending_run: GlobalBoardRun = null
## A board fetch asked for and not started yet (`_fetch_board`).
var _board_wanted: bool = false


func _ready() -> void:
	if config == null:
		config = BenchConfig.load_file()
	_board_request = HTTPRequest.new()
	_board_request.name = "BoardRequest"
	add_child(_board_request)
	_board_request.request_completed.connect(_on_board_request_completed)
	_run_request = HTTPRequest.new()
	_run_request.name = "RunRequest"
	add_child(_run_request)
	_run_request.request_completed.connect(_on_run_request_completed)


## Forgets this process's last fetch, so the next open fetches again. Tests.
static func forget_fetch() -> void:
	_fetched_text = ""
	_fetched_at_ms = -1


## §16.6: the local board at once, then — network allowed and nothing fetched
## within the window — one fetch.
func open_board(allow_network: bool) -> void:
	_ensure_config()
	_read_local()
	if allow_network and _is_fresh():
		var fetched: GlobalBoard = GlobalBoard.parse(_fetched_text, config)
		if fetched.is_usable():
			board_changed.emit(fetched, SOURCE_ONLINE, false)
			return
	board_changed.emit(_local, _local_source, allow_network)
	if allow_network:
		_fetch_board()


## §16.6: a listed run, from the cache when it is there with the verified hash,
## else downloaded. The answer is `run_ready`.
func download_run(run: GlobalBoardRun, allow_network: bool) -> void:
	_ensure_config()
	var cached: String = _run_cache_path(run)
	if FileAccess.file_exists(cached):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(cached)
		if sha256_hex(bytes) == run.sha256:
			var entry: BenchEntry = BenchEntry.from_bytes(bytes)
			if entry != null:
				run_ready.emit(entry, "")
				return
	if not allow_network:
		run_ready.emit(null, FAIL_OFF)
		return
	_pending_run = run
	requests_made += 1
	if not local_board_path.is_empty():
		var path: String = local_board_path.get_base_dir().path_join(run.file)
		var found: bool = FileAccess.file_exists(path)
		handle_run_response(run, HTTPRequest.RESULT_SUCCESS, STATUS_OK if found else 0,
			FileAccess.get_file_as_bytes(path) if found else PackedByteArray())
		return
	if _run_request == null:
		handle_run_response(run, HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		return
	_run_request.cancel_request()
	_run_request.timeout = float(config.global_timeout_s)
	_run_request.body_size_limit = config.global_max_run_bytes
	if _run_request.request(config.global_run_base_url + run.file) != OK:
		handle_run_response(run, HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())


## Stops whatever is under way; nothing more is emitted for it.
func cancel() -> void:
	_pending_run = null
	_board_wanted = false
	if _board_request != null:
		_board_request.cancel_request()
	if _run_request != null:
		_run_request.cancel_request()


## Whether a run's download is under way.
func is_downloading() -> bool:
	return _pending_run != null


## The board fetch's answer (§16.6 step 2): 200 and a usable board → shown as
## online and cached; anything else keeps the local board.
func handle_board_response(result: int, code: int, body: PackedByteArray) -> void:
	_ensure_config()
	if result == HTTPRequest.RESULT_SUCCESS and code == STATUS_OK \
			and BenchEntry.is_utf8(body):
		var text: String = body.get_string_from_utf8()
		var board: GlobalBoard = GlobalBoard.parse(text, config)
		if board.is_usable():
			_fetched_text = text
			_fetched_at_ms = _now()
			_write_board_cache(text, board)
			board_changed.emit(board, SOURCE_ONLINE, false)
			return
	board_changed.emit(_local, _local_source, false)


## A run's download answered (§16.6 steps 2–3).
func handle_run_response(run: GlobalBoardRun, result: int, code: int,
		body: PackedByteArray) -> void:
	if _pending_run != run:
		return
	_pending_run = null
	if result != HTTPRequest.RESULT_SUCCESS or code != STATUS_OK:
		run_ready.emit(null, FAIL_OFFLINE)
		return
	if sha256_hex(body) != run.sha256:
		run_ready.emit(null, FAIL_CHANGED)
		return
	var entry: BenchEntry = BenchEntry.from_bytes(body)
	if entry == null:
		run_ready.emit(null, FAIL_UNREADABLE)
		return
	_write_run_cache(run, body)
	run_ready.emit(entry, "")


## The cached board and the build's copy, the newer one as the local board.
func _read_local() -> void:
	var cache: GlobalBoard = _read_board(cache_dir.path_join(BOARD_FILE))
	var shipped: GlobalBoard = _read_board(shipped_path)
	_local = GlobalBoard.newer(cache, shipped)
	if _local == null:
		_local_source = SOURCE_NONE
	else:
		_local_source = SOURCE_CACHE if _local == cache else SOURCE_SHIPPED


## The local board and where it came from, without any network. The title
## asks this to decide whether the list has anything to show (§16.6).
func local_board() -> GlobalBoard:
	_ensure_config()
	_read_local()
	return _local


static func sha256_hex(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()


func _fetch_board() -> void:
	requests_made += 1
	if not local_board_path.is_empty():
		var found: bool = FileAccess.file_exists(local_board_path)
		handle_board_response(HTTPRequest.RESULT_SUCCESS, STATUS_OK if found else 0,
			FileAccess.get_file_as_bytes(local_board_path) if found else PackedByteArray())
		return
	if _board_request == null:
		handle_board_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		return
	# At the end of the frame: the list is opened before its host moves it into
	# its slot, and an `HTTPRequest` leaving the tree drops its request without
	# a word — the list would say *loading* for ever.
	_board_wanted = true
	_start_board_request.call_deferred()


func _start_board_request() -> void:
	if not _board_wanted:
		return
	_board_wanted = false
	if not _board_request.is_inside_tree():
		handle_board_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
		return
	_board_request.cancel_request()
	_board_request.timeout = float(config.global_timeout_s)
	_board_request.body_size_limit = config.global_max_board_bytes
	if _board_request.request(config.global_leaderboard_url) != OK:
		handle_board_response(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())


func _read_board(path: String) -> GlobalBoard:
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() > config.global_max_board_bytes or not BenchEntry.is_utf8(bytes):
		return null
	return GlobalBoard.parse(bytes.get_string_from_utf8(), config)


## The fetched file replaces the cache unless the cache is newer.
func _write_board_cache(text: String, board: GlobalBoard) -> void:
	var path: String = cache_dir.path_join(BOARD_FILE)
	var cached: GlobalBoard = _read_board(path)
	if cached != null and cached.is_usable() and cached.generated > board.generated:
		return
	_write_atomic(path, text.to_utf8_buffer())


func _write_run_cache(run: GlobalBoardRun, body: PackedByteArray) -> void:
	if config.global_cache_runs_max <= 0:
		return
	var dir: String = cache_dir.path_join(RUNS_DIR)
	_write_atomic(_run_cache_path(run), body)
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if not file_name.ends_with(TMP_SUFFIX):
			files.append(dir.path_join(file_name))
	if files.size() <= config.global_cache_runs_max:
		return
	# The oldest go first; the one just written is the newest.
	files.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) < FileAccess.get_modified_time(b))
	for i: int in files.size() - config.global_cache_runs_max:
		DirAccess.remove_absolute(files[i])


## `.tmp`, then a rename: a crash mid-write never leaves half a file.
static func _write_atomic(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp: String = path + TMP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("global leaderboard: cannot write %s" % tmp)
		return
	file.store_buffer(bytes)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)


func _run_cache_path(run: GlobalBoardRun) -> String:
	return cache_dir.path_join(RUNS_DIR).path_join(run.file.get_file())


func _is_fresh() -> bool:
	return _fetched_at_ms >= 0 and not _fetched_text.is_empty() \
		and _now() - _fetched_at_ms < config.global_min_refetch_s * MS_PER_SECOND


func _now() -> int:
	return clock_override_ms if clock_override_ms >= 0 else Time.get_ticks_msec()


func _ensure_config() -> void:
	if config == null:
		config = BenchConfig.load_file()


func _on_board_request_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	handle_board_response(result, code, body)


func _on_run_request_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if _pending_run != null:
		handle_run_response(_pending_run, result, code, body)
