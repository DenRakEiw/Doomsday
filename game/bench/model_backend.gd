class_name ModelBackend
extends RefCounted
## Where a model's answers come from (docs/specs/benchmark.md §8.1, §17.4): a mock
## that answers from the typed digest, or a service over HTTP (the tool's own
## backends, which never ship). A backend is of one of two kinds: a chat model
## writes text (`answer`), a decision model ranks the options it is offered
## (`choose`).

const KIND_CHAT: String = "chat"
const KIND_CHOICE: String = "choice"


## `KIND_CHAT` unless a backend says otherwise.
func kind() -> String:
	return KIND_CHAT


## One answer for one request. Blocking: the headless tool has nothing else to do
## meanwhile. `digest` is there so that a mock can answer from the typed state; a
## real backend ignores it. `params` are the run's parameters plus `seed`.
@warning_ignore("unused_parameter")
func answer(messages: Array[Dictionary], digest: BenchDigest, params: Dictionary) -> ModelReply:
	return ModelReply.fatal("no_backend")


## A choice backend's answer to one plan (§17.2): the service's reply as
## `ModelReply.body`, read afterwards by `BenchChoice.read`. Blocking, as `answer`.
@warning_ignore("unused_parameter")
func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply:
	return ModelReply.fatal("no_backend")


## `"openrouter"`, `"mock:cheapest"`, `"typesafe"`, …
func backend_id() -> String:
	return ""
