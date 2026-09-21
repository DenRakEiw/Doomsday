class_name SimRng
extends RefCounted
## The only source of randomness in the simulation.
##
## Seed and state are signed 64-bit and are passed around **as strings**: a JSON
## number loses the low bits, and a restored run would then diverge a few hundred
## ticks later without anything looking wrong.
##
## Bots get their own generator, so that a policy can never perturb the world's
## stream (core.md §11).

var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()


static func from_seed(seed_value: int) -> SimRng:
	var rng: SimRng = SimRng.new()
	rng._rng.seed = seed_value
	return rng


## Continues a stream exactly where `seed_string`/`state_string` left it.
static func from_strings(seed_text: String, state_text: String) -> SimRng:
	var rng: SimRng = SimRng.new()
	# The seed first: assigning it resets the state.
	rng._rng.seed = seed_text.to_int()
	rng._rng.state = state_text.to_int()
	return rng


func seed_string() -> String:
	return str(_rng.seed)


func state_string() -> String:
	return str(_rng.state)


func randf() -> float:
	return _rng.randf()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Consumes exactly one value, whatever `p` is — a roll the caller skips and a
## roll that cannot fail must both leave the stream where the spec says it is.
func chance(p: float) -> bool:
	return _rng.randf() < p
