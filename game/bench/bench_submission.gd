class_name BenchSubmission
extends RefCounted
## One group of run files prepared for `public.submit_runs`
## (docs/specs/benchmark.md §20.2, §20.3, §20.5), and the reader for the
## server's answer. Pure — no network, no autoload named.

const STATUS_OK: int = 200
const STATUS_BAD_REQUEST: int = 400
const STATUS_CLIENT_MAX: int = 499
const SUBMIT_PREFIX: String = "submit:"
const FIELD_FILES: String = "p_files"
const FIELD_NAME: String = "name"
const FIELD_BODY: String = "body"
const FIELD_STATUS: String = "status"
const FIELD_ID: String = "id"
const FIELD_MESSAGE: String = "message"
const REASON_BUSY: String = "busy"
const REASON_FULL: String = "full"
const REASON_CLOSED: String = "closed"
const REASON_MAX: int = 32

## Why the last `from_group` returned `null`.
static var last_error: String = ""

## `[{"name": String, "body": String}, …]` in the group's order.
var files: Array[Dictionary] = []
## Each file's lower-case hex SHA-256, in the group's order.
var file_sha: PackedStringArray = PackedStringArray()
## §20.2: the lower-case hex SHA-256 of the sorted `file_sha` joined with `"\n"`.
var group_sha: String = ""
var total_bytes: int = 0


## Reads `group`'s files and checks `config`'s size rules before any request is
## made (§20.5). Returns `null` and sets `last_error` when a file cannot be read,
## is not UTF-8, or breaks a size limit.
static func from_group(group: BenchGroup, config: BenchConfig = null) -> BenchSubmission:
	last_error = ""
	if config == null:
		config = BenchConfig.load_file()
	if group == null or group.paths.is_empty() or group.paths.size() != group.entries.size():
		last_error = "no group files"
		return null
	if group.paths.size() > config.submit_max_files:
		last_error = "more than %d files" % config.submit_max_files
		return null
	var submission: BenchSubmission = BenchSubmission.new()
	for i: int in group.paths.size():
		var path: String = group.paths[i]
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			last_error = "%s: cannot be opened" % path
			return null
		var size: int = file.get_length()
		if size <= 0 or size > config.submit_max_file_bytes:
			last_error = "%s: %d bytes" % [path, size]
			return null
		var bytes: PackedByteArray = file.get_buffer(size)
		if not BenchEntry.is_utf8(bytes):
			last_error = "%s: not UTF-8" % path
			return null
		submission.total_bytes += bytes.size()
		if submission.total_bytes > config.submit_max_total_bytes:
			last_error = "total %d bytes above %d" % [submission.total_bytes,
				config.submit_max_total_bytes]
			return null
		var text: String = bytes.get_string_from_utf8()
		submission.files.append({
			FIELD_NAME: group.entries[i].file_name(),
			FIELD_BODY: text,
		})
		submission.file_sha.append(sha256_hex(bytes))
	submission.group_sha = group_sha_of(submission.file_sha)
	return submission


## The §20.3 request body.
func body() -> String:
	return JSON.stringify({FIELD_FILES: files})


## §20.3: the publishable key goes in `apikey` only, never `Authorization`.
func headers(config: BenchConfig) -> PackedStringArray:
	return headers_for(config.submit_publishable_key)


static func headers_for(publishable_key: String) -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + publishable_key,
		"Content-Type: application/json",
		"Accept: application/json",
	])


## §20.2's group hash: the sorted file hashes joined with `"\n"`, hashed again.
static func group_sha_of(hashes: PackedStringArray) -> String:
	var sorted: Array[String] = []
	for h: String in hashes:
		sorted.append(h)
	sorted.sort()
	return sha256_hex("\n".join(sorted).to_utf8_buffer())


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Reads the HTTP status and body of a `submit_runs` call into a
## `BenchSubmitResult` (§20.3, §20.5).
static func read_answer(code: int, body_bytes: PackedByteArray) -> BenchSubmitResult:
	if code <= 0:
		return BenchSubmitResult.of(BenchSubmitResult.NETWORK, "no_response")
	var parsed: Variant = null
	if BenchEntry.is_utf8(body_bytes):
		var json: JSON = JSON.new()
		if json.parse(body_bytes.get_string_from_utf8()) == OK:
			parsed = json.data
	if code == STATUS_OK:
		if typeof(parsed) != TYPE_DICTIONARY:
			return BenchSubmitResult.of(BenchSubmitResult.NETWORK, "bad_200")
		var d: Dictionary = parsed
		var status: String = str(d.get(FIELD_STATUS, ""))
		var row_id: int = int(d[FIELD_ID]) if typeof(d.get(FIELD_ID)) in [TYPE_INT, TYPE_FLOAT] else 0
		if status == BenchSubmitResult.RECEIVED:
			return BenchSubmitResult.of(BenchSubmitResult.RECEIVED, status, row_id)
		if status == BenchSubmitResult.ALREADY:
			return BenchSubmitResult.of(BenchSubmitResult.ALREADY, status, row_id)
		return BenchSubmitResult.of(BenchSubmitResult.NETWORK, "bad_status")
	if code >= STATUS_BAD_REQUEST and code <= STATUS_CLIENT_MAX:
		if typeof(parsed) == TYPE_DICTIONARY:
			var message: String = str((parsed as Dictionary).get(FIELD_MESSAGE, ""))
			if message.begins_with(SUBMIT_PREFIX):
				var reason: String = _clean_reason(message.trim_prefix(SUBMIT_PREFIX))
				if reason == REASON_BUSY or reason == REASON_FULL:
					return BenchSubmitResult.of(BenchSubmitResult.BUSY, reason)
				if reason == REASON_CLOSED:
					return BenchSubmitResult.of(BenchSubmitResult.CLOSED, reason)
				return BenchSubmitResult.of(BenchSubmitResult.REFUSED,
					reason if not reason.is_empty() else "submit")
		return BenchSubmitResult.of(BenchSubmitResult.REFUSED, "http_%d" % code)
	return BenchSubmitResult.of(BenchSubmitResult.NETWORK, "http_%d" % code)


static func _clean_reason(raw: String) -> String:
	var out: String = ""
	for i: int in mini(raw.length(), REASON_MAX):
		var c: int = raw.unicode_at(i)
		if (c >= 0x61 and c <= 0x7A) or (c >= 0x30 and c <= 0x39) or c == 0x5F:
			out += char(c)
		else:
			break
	return out
