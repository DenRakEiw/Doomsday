extends RefCounted
## The benchmark's answer cache (docs/specs/benchmark.md §9): request → *parsed*
## answer, one file per answer, so a repeated run costs nothing and never keeps a
## model's text. Written to `<name>.tmp` and renamed, so parallel shards never
## corrupt one another. Local and git-ignored.
##
## A tool, so no `class_name`; `bench_run.gd` and the tests preload it.

const FIELD_MODEL: String = "model"
const FIELD_PARAMS: String = "params"
const FIELD_PROMPT_VERSION: String = "prompt_version"
const FIELD_PARSER_VERSION: String = "parser_version"
const FIELD_MESSAGES: String = "messages"
const SHARD_LENGTH: int = 2
const EXTENSION: String = ".json"
const TEMP_SUFFIX: String = ".tmp"

var root: String = ""


func _init(p_root: String) -> void:
	root = p_root.trim_suffix("/")


## SHA-256 (hex) of the sorted JSON of everything that decides an answer: a
## changed parameter, prompt or parser version, or a retry's extra message is a
## different key.
static func key(model: String, params: Dictionary, prompt_version: int, parser_version: int,
		messages: Array[Dictionary]) -> String:
	return JSON.stringify({
		FIELD_MODEL: model,
		FIELD_PARAMS: params,
		FIELD_PROMPT_VERSION: prompt_version,
		FIELD_PARSER_VERSION: parser_version,
		FIELD_MESSAGES: messages,
	}, "", true).sha256_text()


## `<root>/<model slug>/<key[0..2]>/<key>.json`.
func path_for(model: String, cache_key: String) -> String:
	return "%s/%s/%s/%s%s" % [root, BenchEntry.slug(model), cache_key.substr(0, SHARD_LENGTH),
		cache_key, EXTENSION]


## The stored value, or {} on a miss — which is also what a file that does not
## read back as an answer is.
func read(model: String, cache_key: String) -> Dictionary:
	var path: String = path_for(model, cache_key)
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK \
			or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var value: Dictionary = json.data
	if typeof(value.get(ModelPolicy.CACHE_ANSWER)) != TYPE_DICTIONARY \
			or BenchAnswer.from_cache(value[ModelPolicy.CACHE_ANSWER]) == null:
		return {}
	return value


## Writes one answer; false when the file could not be written.
func write(model: String, cache_key: String, value: Dictionary) -> bool:
	var path: String = path_for(model, cache_key)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temp: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "\t", true))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp, path) == OK


## The policy's two hooks for one model and its parameters (`ModelPolicy`).
## `read_enabled` false is `--fresh`: nothing is read, everything is written.
func hooks(model: String, params: Dictionary, prompt_version: int, parser_version: int,
		read_enabled: bool) -> Dictionary:
	var reader: Callable = func(messages: Array[Dictionary]) -> Dictionary:
		return read(model, key(model, params, prompt_version, parser_version, messages))
	var writer: Callable = func(messages: Array[Dictionary], value: Dictionary) -> void:
		write(model, key(model, params, prompt_version, parser_version, messages), value)
	return {"read": reader if read_enabled else Callable(), "write": writer}
