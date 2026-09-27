extends PanelContainer
## The strip over a watched benchmark run (spec benchmark.md §12.5): who is
## playing, which seed, how hard the model was asked to think (§18; a dash for
## a bot or a decision model), the stance the model last took and which of its
## decisions the replay has reached.
##
## Shown only while `Game.is_spectating()`. One line at full width; in compact
## the flow wraps to two, never scrolls. A screen reader hears it as one readout
## (accessibility.md §3.2 rules 3–4); the console line speaks the changes.
##
## Scene-specific, so no `class_name`.

const KEY_WATCHING: String = "UI_SPECTATOR_WATCHING"
const KEY_SEED: String = "UI_SPECTATOR_SEED"
const KEY_STANCE: String = "UI_SPECTATOR_STANCE"
const KEY_DECISION: String = "UI_SPECTATOR_DECISION"
const KEY_UNREADABLE: String = "UI_SPECTATOR_UNREADABLE"
const KEY_A11Y: String = "UI_A11Y_SPECTATOR"
const PLACEHOLDER_SEED: String = "seed"
const PLACEHOLDER_STANCE: String = "stance"
const PLACEHOLDER_DECISION: String = "decision"
const PLACEHOLDER_TOTAL: String = "total"
const PLACEHOLDER_COUNT: String = "count"
const PLACEHOLDER_MODEL: String = "model"
const PLACEHOLDER_EFFORT: String = "effort"

@onready var _watching: CapsLabel = %SpectatorWatching
@onready var _model: Label = %SpectatorModel
@onready var _seed_label: Label = %SpectatorSeed
@onready var _effort: Label = %SpectatorEffort
@onready var _stance: Chip = %SpectatorStance
@onready var _decision: Label = %SpectatorDecision
@onready var _unreadable: Label = %SpectatorUnreadable


func _ready() -> void:
	# The strip is the readout; the chip inside it is not a second one.
	_stance.focus_mode = Control.FOCUS_NONE
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Shows or hides the strip and fills it from the replay at the current day.
func refresh() -> void:
	visible = Game.is_spectating() and Game.sim != null
	if not visible:
		return
	var replay: ReplayPolicy = Game.spectator()
	var entry: BenchEntry = replay.entry
	var day: int = Game.sim.world.day
	var decision: BenchDecision = replay.decision_at(day)
	var stance: String = BenchPrompt.stance_name("" if decision == null else decision.stance)
	var index: int = replay.decision_index(day)
	var total: int = entry.decisions.size()
	var has_decisions: bool = total > 0
	_model.text = entry.model
	_seed_label.text = tr(KEY_SEED).format({PLACEHOLDER_SEED: entry.seed_value})
	var effort: String = BenchEffort.label(BenchEffort.of_entry(entry))
	_effort.text = BenchEffort.line(BenchEffort.of_entry(entry))
	_stance.visible = has_decisions
	_stance.set_label(KEY_STANCE, {PLACEHOLDER_STANCE: stance})
	_decision.visible = has_decisions
	_decision.text = tr(KEY_DECISION).format({PLACEHOLDER_DECISION: index,
		PLACEHOLDER_TOTAL: total})
	_unreadable.visible = has_decisions and entry.invalid_answers > 0
	_unreadable.text = tr(KEY_UNREADABLE).format({PLACEHOLDER_COUNT: entry.invalid_answers})
	A11y.readout(self, tr(KEY_WATCHING), tr(KEY_A11Y).format({
		PLACEHOLDER_MODEL: entry.model,
		PLACEHOLDER_SEED: entry.seed_value,
		PLACEHOLDER_EFFORT: effort,
		PLACEHOLDER_DECISION: index,
		PLACEHOLDER_TOTAL: total,
		PLACEHOLDER_STANCE: stance,
	}))


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_tick_advanced(_day: int) -> void:
	if Game.is_spectating():
		refresh()
