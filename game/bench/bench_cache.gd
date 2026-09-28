class_name BenchCache
extends RefCounted
## The benchmark's answer cache (docs/specs/benchmark.md §9, §17.7): request →
## *parsed* (or, for a decision model, combined) answer, one file per answer, so
## a repeated run costs nothing and never keeps a model's text. Written to
## `<name>.tmp` and renamed, so parallel shards never corrupt one another. Local
## and git-ignored.
##
## In `game/bench/` since S6.12f (§19.3): the tool and the game's worker share it;
## the root is an argument (`user://benchmark/cache/` for the worker).

const FIELD_MODEL: String = "model"
const FIELD_PARAMS: String = "params"
const FIELD_PROMPT_VERSION: String = "prompt_version"
const FIELD_PARSER_VERSION: String = "parser_version"
const SHARD_LENGTH: int = 2
const EXTENSION: String = ".json"
const TEMP_SUFFIX: String = ".tmp"

var root: String = ""


func _init(p_root: String) -> void:
	root = p_root.trim_suffix("/")


## SHA-256 (hex) of the sorted JSON of everything that decides an answer: a
## changed parameter, prompt or parser version, or a different request is a
## different key. The request is its `basis` (§9, §17.7): a chat request's is
## `{"messages": …}` — so the object, and every chat key, is what it was before
## decision models — a choice request's its plan's state and questions, plus the
## attempt of a retry.
static func key(model: String, params: Dictionary, prompt_version: int, parser_version: int,
		basis: Dictionary) -> String:
	var object: Dictionary = {
		FIELD_MODEL: model,
		FIELD_PARAMS: params,
		FIELD_PROMPT_VERSION: prompt_version,
		FIELD_PARSER_VERSION: parser_version,
	}
	object.merge(basis)
	return JSON.stringify(object, "", true).sha256_text()


## A chat request's basis: its messages.
static func chat_basis(messages: Array[Dictionary]) -> Dictionary:
	return {ModelPolicy.BASIS_MESSAGES: messages}


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
	var reader: Callable = func(basis: Dictionary) -> Dictionary:
		return read(model, key(model, params, prompt_version, parser_version, basis))
	var writer: Callable = func(basis: Dictionary, value: Dictionary) -> void:
		write(model, key(model, params, prompt_version, parser_version, basis), value)
	return {"read": reader if read_enabled else Callable(), "write": writer}
