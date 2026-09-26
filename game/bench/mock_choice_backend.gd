class_name MockChoiceBackend
extends ModelBackend
## A decision model without a service (docs/specs/benchmark.md §17.10): it
## answers a plan with a body shaped like the service's, so every reply goes
## through the real reader and combiner. Deterministic — no clock, no random
## numbers — and free; like the chat mocks it never uses the cache.

const MODE_FIRST: String = "first"
const MODE_IDLE: String = "idle"
const MODE_SHUFFLED: String = "shuffled"
const MODE_BROKEN: String = "broken"
const MODES: Array[String] = ["first", "idle", "shuffled", "broken"]
const ID_PREFIX: String = "mock-choice:"
## The version every reply names.
const MODEL_VERSION: String = "mock-choice-1"
## `broken`: every third call answers no `answers`; every fourth leaves out the
## `buy` answer and gives `stance` a choice it was not offered.
const BROKEN_NO_ANSWERS_EVERY: int = 3
const BROKEN_PROBLEMS_EVERY: int = 4
const UNOFFERED_CHOICE: String = "no_such_option"
## `shuffled`: the leading hex digits of a SHA-256 read as a weight.
const SHUFFLE_HEX_DIGITS: int = 8
## `first`: each key weighs half the one before it.
const FIRST_RATIO: float = 0.5

var mode: String = MODE_FIRST
## Calls answered so far, 1-based once the first is made.
var calls: int = 0


func _init(p_mode: String = MODE_FIRST) -> void:
	mode = p_mode


## The mode an id like `mock-choice:first` names, or "" when it is not one.
static func mode_of(backend: String) -> String:
	if not backend.begins_with(ID_PREFIX):
		return ""
	var named: String = backend.substr(ID_PREFIX.length())
	return named if MODES.has(named) else ""


func kind() -> String:
	return KIND_CHOICE


func backend_id() -> String:
	return ID_PREFIX + mode


func choose(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> ModelReply:
	calls += 1
	return ModelReply.choice(body_for(plan, digest, params), MODEL_VERSION)


## The service-shaped body for this call (§17.1): `model`, `answers`, `usage`.
func body_for(plan: BenchChoicePlan, digest: BenchDigest, params: Dictionary) -> Dictionary:
	var body: Dictionary = {
		BenchChoice.FIELD_MODEL: MODEL_VERSION,
		BenchChoice.FIELD_USAGE: {BenchChoice.FIELD_INPUT_TOKENS: 0,
			BenchChoice.FIELD_OUTPUT_TOKENS: 0},
	}
	if mode == MODE_BROKEN and calls % BROKEN_NO_ANSWERS_EVERY == 0:
		return body
	var problems: bool = mode == MODE_BROKEN and calls % BROKEN_PROBLEMS_EVERY == 0
	var answers: Dictionary = {}
	for question: String in plan.keys:
		if problems and question == BenchChoice.Q_BUY:
			continue
		var keys: Array[String] = plan.keys_of(question)
		if problems and question == BenchChoice.Q_STANCE:
			var zeros: Dictionary = {}
			for key: String in keys:
				zeros[key] = 0.0
			answers[question] = _answer(UNOFFERED_CHOICE, zeros)
			continue
		var weights: Array[float] = _weights(question, keys, digest, params)
		var total: float = 0.0
		for weight: float in weights:
			total += weight
		var probabilities: Dictionary = {}
		var best: int = 0
		for i: int in keys.size():
			probabilities[keys[i]] = weights[i] / total if total > 0.0 else 0.0
			if weights[i] > weights[best]:
				best = i
		answers[question] = _answer(keys[best], probabilities)
	body[BenchChoice.FIELD_ANSWERS] = answers
	return body


## One weight per key before normalising, as the mode says.
func _weights(question: String, keys: Array[String], digest: BenchDigest,
		params: Dictionary) -> Array[float]:
	var out: Array[float] = []
	match mode:
		MODE_IDLE:
			var wanted: String = _idle_key(question, keys)
			for key: String in keys:
				out.append(1.0 if key == wanted else 0.0)
		MODE_SHUFFLED:
			var seed_text: String = str(params.get(ModelPolicy.PARAM_SEED, 0))
			for key: String in keys:
				var hash_text: String = "%s:%d:%s:%s" % [seed_text, digest.day, question, key]
				var digits: String = hash_text.sha256_text().substr(0, SHUFFLE_HEX_DIGITS)
				out.append(float(digits.hex_to_int()))
		_:
			# `first` (and `broken` between its faults): the plan's order, the control
			# key already last; the stance `spread` on top.
			var weight: float = FIRST_RATIO
			for key: String in keys:
				out.append(weight)
				weight *= FIRST_RATIO
			if question == BenchChoice.Q_STANCE:
				var spread: int = keys.find(BenchAnswer.STANCE_SPREAD)
				if spread >= 0:
					out[spread] = 1.0
	return out


## `idle`: the control key where there is one, `wait` for the stance, else the
## first key (a run needs an origin, and a site or target is only used when its
## node or ability is picked).
static func _idle_key(question: String, keys: Array[String]) -> String:
	if question == BenchChoice.Q_STANCE:
		return BenchAnswer.STANCE_WAIT
	for control: String in BenchChoice.CONTROL_KEYS:
		if keys.has(control):
			return control
	return keys[0]


static func _answer(choice: String, probabilities: Dictionary) -> Dictionary:
	var confidence: float = 0.0
	for key: Variant in probabilities:
		confidence = maxf(confidence, float(probabilities[key]))
	return {BenchChoice.FIELD_TYPE: BenchChoice.TYPE_CHOICE, BenchChoice.FIELD_CHOICE: choice,
		BenchChoice.FIELD_PROBABILITIES: probabilities, BenchChoice.FIELD_CONFIDENCE: confidence}
