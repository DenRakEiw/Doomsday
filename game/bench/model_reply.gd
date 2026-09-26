class_name ModelReply
extends RefCounted
## One backend's answer to one request (docs/specs/benchmark.md §8.1, §17.4).

const OK: String = "ok"
## The run cannot continue: auth, credits, a bad request, a service down after
## its retries, or the cost cap.
const FATAL: String = "fatal"

var status: String = OK
## The model's content; "" when it sent none.
var text: String = ""
## For `FATAL`: a short reason — never the key, never a header.
var error: String = ""
var tokens_in: int = 0
var tokens_out: int = 0
var cost_usd: float = 0.0
## `finish_reason` as the service reported it.
var finish: String = ""
## A choice backend's parsed reply (§17.1's shape); {} for a chat backend.
var body: Dictionary = {}
## "" or a §17.5 answer error: the backend already knows the reply is unreadable.
var invalid: String = ""
## The model version the service reported, e.g. `jev-1.13.0`; "" when it names none.
var model_version: String = ""


static func ok(p_text: String) -> ModelReply:
	var reply: ModelReply = ModelReply.new()
	reply.text = p_text
	return reply


## A choice backend's reply: the service's body and the version it named.
static func choice(p_body: Dictionary, p_model_version: String = "") -> ModelReply:
	var reply: ModelReply = ModelReply.new()
	reply.body = p_body
	reply.model_version = p_model_version
	return reply


static func fatal(reason: String) -> ModelReply:
	var reply: ModelReply = ModelReply.new()
	reply.status = FATAL
	reply.error = reason
	return reply


func is_fatal() -> bool:
	return status == FATAL
