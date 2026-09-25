class_name ModelReply
extends RefCounted
## One backend's answer to one request (docs/specs/benchmark.md §8.1).

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


static func ok(p_text: String) -> ModelReply:
	var reply: ModelReply = ModelReply.new()
	reply.text = p_text
	return reply


static func fatal(reason: String) -> ModelReply:
	var reply: ModelReply = ModelReply.new()
	reply.status = FATAL
	reply.error = reason
	return reply


func is_fatal() -> bool:
	return status == FATAL
