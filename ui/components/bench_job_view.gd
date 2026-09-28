class_name BenchJobView
extends VBoxContainer
## The player's own benchmark as it runs (docs/specs/benchmark.md §19.9.1): the
## model, its effort, one line per seed — waiting, playing, done — the cost
## against the cap, *Stop*, and at the end how it went. The benchmark modal and
## the Benchmark list both show it; it reads `BenchJobs` and redraws on its
## `changed`.
##
## The model id is data from outside: a plain `Label`. The owner hands in a
## live region (one that sits outside any container), which hears the start,
## each finished seed and the end — never every decision.

const KEY_TITLE: String = "UI_BENCH_JOB_TITLE"
const KEY_WAITING: String = "UI_BENCH_JOB_SEED_WAITING"
const KEY_SEED: String = "UI_BENCH_JOB_SEED"
const KEY_SEED_DONE: String = "UI_BENCH_JOB_SEED_DONE"
const KEY_COST: String = "UI_BENCH_JOB_COST"
const KEY_STOP: String = "UI_BENCH_JOB_STOP"
const KEY_DONE: String = "UI_BENCH_JOB_DONE"
const KEY_STOPPED: String = "UI_BENCH_JOB_STOPPED"
const PREFIX_FAIL: String = "UI_BENCH_JOB_FAIL_"
const PREFIX_OUTCOME: String = "UI_OUTCOME_"
## The keys built at run time, for the strings check.
const KEYS: Array[String] = ["UI_BENCH_JOB_FAIL_AUTH", "UI_BENCH_JOB_FAIL_CREDITS",
	"UI_BENCH_JOB_FAIL_FORBIDDEN", "UI_BENCH_JOB_FAIL_BAD_REQUEST",
	"UI_BENCH_JOB_FAIL_UNAVAILABLE", "UI_BENCH_JOB_FAIL_COST_CAP", "UI_BENCH_JOB_FAIL_ERROR"]
const USD_DECIMALS: int = 2
const SCORE_DECIMALS: int = 1
const SEPARATOR: String = " · "

## Whether the section heading shows (the list's section has it, the modal's
## title says it already).
var show_title: bool = true
## Where the start, each finished seed and the end are spoken; may stay null.
var live: LiveRegion = null

var _title: CapsLabel = null
var _model: Label = null
var _effort: Label = null
var _seeds: VBoxContainer = null
var _cost: Label = null
var _end: Label = null
var _reason: Label = null
var _stop: ConsoleButton = null
## What was last spoken about: the state, the finished seeds, its end.
var _spoken_state: BenchJobState = null
var _spoken_seeds: Array[int] = []
var _spoken_end: bool = false


func _ready() -> void:
	theme_type_variation = &"StackTight"
	_build()
	BenchJobs.changed.connect(refresh)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## The lines as they stand, for the tests: the seeds', then the cost and the end.
func lines() -> Array[String]:
	var out: Array[String] = []
	for child: Node in _seeds.get_children():
		out.append((child as Label).text)
	for label: Label in [_cost, _end, _reason]:
		if label.visible:
			out.append(label.text)
	return out


func stop_button() -> ConsoleButton:
	return _stop


## Redraws from `BenchJobs.state()`; hidden before the first benchmark.
func refresh() -> void:
	if _model == null:
		return
	var state: BenchJobState = BenchJobs.state()
	visible = state != null
	if state == null:
		return
	_title.visible = show_title
	_model.text = state.model
	_effort.text = BenchEffort.line(state.effort)
	for child: Node in _seeds.get_children():
		_seeds.remove_child(child)
		child.queue_free()
	for row: BenchJobSeed in state.seeds:
		var label: Label = _caption(_seeds)
		label.text = seed_line(row)
	_cost.visible = not state.free
	_cost.text = tr(KEY_COST).format({
		"cost": Format.decimal(state.cost_usd(), USD_DECIMALS),
		"cap": Format.decimal(state.cap_usd, USD_DECIMALS),
	})
	_stop.visible = state.is_running()
	_end.visible = not state.is_running()
	_reason.visible = state.status == BenchJobState.STOPPED \
		and state.reason != BenchJobState.REASON_PLAYER
	if state.status == BenchJobState.DONE:
		var runs: int = state.finished_runs()
		_end.text = tr(KEY_DONE).format({"survived": runs - state.wins(), "runs": runs})
	elif state.status == BenchJobState.STOPPED:
		_end.text = tr(KEY_STOPPED)
		_reason.text = tr(PREFIX_FAIL + state.reason.to_upper())
	_speak(state)


## §19.9.1's line for one seed.
func seed_line(row: BenchJobSeed) -> String:
	if row.finished:
		return tr(KEY_SEED_DONE).format({"seed": row.seed_value,
			"outcome": tr(PREFIX_OUTCOME + row.outcome.to_upper()),
			"score": Format.decimal(row.score, SCORE_DECIMALS)})
	if row.started:
		return tr(KEY_SEED).format({"seed": row.seed_value, "day": row.day, "calls": row.calls})
	return tr(KEY_WAITING).format({"seed": row.seed_value})


## The start, each seed as it finishes, the end — each once.
func _speak(state: BenchJobState) -> void:
	if live == null:
		return
	if state != _spoken_state:
		_spoken_state = state
		_spoken_seeds.clear()
		_spoken_end = not state.is_running()
		if state.is_running():
			live.say(_model.text + SEPARATOR + _effort.text)
		for row: BenchJobSeed in state.seeds:
			if row.finished:
				_spoken_seeds.append(row.seed_value)
		return
	for row: BenchJobSeed in state.seeds:
		if row.finished and not _spoken_seeds.has(row.seed_value):
			_spoken_seeds.append(row.seed_value)
			live.say(seed_line(row))
	if not state.is_running() and not _spoken_end:
		_spoken_end = true
		live.say(_end.text + (" " + _reason.text if _reason.visible else ""))


func _build() -> void:
	_title = CapsLabel.new()
	_title.label_key = KEY_TITLE
	add_child(_title)
	_model = Label.new()
	_model.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	add_child(_model)
	_effort = _caption(self)
	_seeds = VBoxContainer.new()
	_seeds.theme_type_variation = &"StackLines"
	add_child(_seeds)
	_cost = _caption(self)
	_end = _caption(self)
	_end.theme_type_variation = &"LabelCaptionAccent"
	_reason = _caption(self)
	_reason.theme_type_variation = &"LabelCaptionAlert"
	_stop = ConsoleButton.new()
	_stop.label_key = KEY_STOP
	_stop.alert = true
	_stop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stop.pressed.connect(BenchJobs.stop)
	add_child(_stop)


static func _caption(into: Container) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"LabelCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	into.add_child(label)
	return label
