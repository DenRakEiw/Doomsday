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


## An index drawn in proportion to its weight, consuming exactly **one** value.
## A negative or non-finite weight counts as 0. A total of 0 or less returns -1
## and consumes nothing: there was nothing to draw from, and a roll spent on an
## empty list would shift every later draw.
func weighted_pick(weights: PackedFloat64Array) -> int:
	var total: float = 0.0
	for weight: float in weights:
		if is_finite(weight) and weight > 0.0:
			total += weight
	if total <= 0.0:
		return -1
	var point: float = _rng.randf() * total
	var running: float = 0.0
	for i: int in weights.size():
		var weight: float = weights[i]
		if not is_finite(weight) or weight <= 0.0:
			continue
		running += weight
		if point < running:
			return i
	# Only reachable when the float sum drifts past the last boundary.
	for i: int in range(weights.size() - 1, -1, -1):
		if is_finite(weights[i]) and weights[i] > 0.0:
			return i
	return -1
