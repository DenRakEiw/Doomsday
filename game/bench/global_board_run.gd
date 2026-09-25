class_name GlobalBoardRun
extends RefCounted
## One verified run of a global leaderboard row (docs/specs/benchmark.md §16.3's
## `seeds`): which file to download for it, and the SHA-256 the download must
## have.

var seed_value: int = 0
## `runs/<name>.json`, relative to the board's repository.
var file: String = ""
## Lower-case hex of the file's SHA-256 as the verifier checked it.
var sha256: String = ""
var outcome: String = ""
var days: int = 0
var score: float = 0.0
