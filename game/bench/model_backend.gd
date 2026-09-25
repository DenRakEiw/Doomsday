class_name ModelBackend
extends RefCounted
## Where a model's answers come from (docs/specs/benchmark.md §8.1): a mock that
## answers from the typed digest, or a chat service over HTTP (the tool's own
## backend, which never ships).


## One answer for one request. Blocking: the headless tool has nothing else to do
## meanwhile. `digest` is there so that a mock can answer from the typed state; a
## real backend ignores it. `params` are the run's parameters plus `seed`.
@warning_ignore("unused_parameter")
func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply:
	return ModelReply.fatal("no_backend")


## `"openrouter"`, `"mock:cheapest"`, …
func backend_id() -> String:
	return ""

