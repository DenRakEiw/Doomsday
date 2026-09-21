class_name LoadResult
extends RefCounted
## What `WorldSerializer.from_json` gives back: a simulation, or the one reason
## there is none.
##
## A refused save changes nothing and never crashes — every field of the file is
## type-checked before it is read, because a save is data we may not have written.

## Null unless `ok()`.
var sim: Simulation = null
## A `WorldSerializer.REASON_*`; empty when the save loaded.
var reason: String = ""
## Loaded, but on different content: the run is playable and a replay of its
## command log would not reproduce it.
var content_mismatch: bool = false


func ok() -> bool:
	return reason.is_empty()


static func refused(reason: String) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	result.reason = reason
	return result
