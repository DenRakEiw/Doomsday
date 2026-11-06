class_name BenchSubmitResult
extends RefCounted
## The answer to one `submit_runs` call (docs/specs/benchmark.md §20.5, §20.6):
## which message and buttons the *Submit* modal shows, and the short reason id
## and row id written to the game's log.

const RECEIVED: String = "received"
const ALREADY: String = "already"
const BUSY: String = "busy"
const CLOSED: String = "closed"
const REFUSED: String = "refused"
const NETWORK: String = "network"

const KIND_RECEIVED: String = RECEIVED
const KIND_ALREADY: String = ALREADY
const KIND_BUSY: String = BUSY
const KIND_CLOSED: String = CLOSED
const KIND_REFUSED: String = REFUSED
const KIND_NETWORK: String = NETWORK

var kind: String = NETWORK
var id: int = 0
## For the game's log line only (`bench_submit: <kind> <reason> <id>`), never
## shown in the UI.
var reason: String = ""


func is_stored() -> bool:
	return kind == RECEIVED or kind == ALREADY


static func of(p_kind: String, p_reason: String = "", p_id: int = 0) -> BenchSubmitResult:
	var result: BenchSubmitResult = BenchSubmitResult.new()
	result.kind = p_kind
	result.reason = p_reason
	result.id = p_id
	return result
