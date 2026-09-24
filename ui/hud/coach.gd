extends PanelContainer
## The guided first run (`first-run.md` §3): a card that says what to do next and
## a ring round the control it means.
##
## Steps 1–5 come in order at the start; 6–10 each come the first time their
## moment does; 11 closes it. The card asks the run and the interface what is the
## case each frame — cheap, and nothing has to remember to tell it. It never holds
## the clock and never blocks input: everything it points at can be done around it.
##
## Scene-specific, so no `class_name`.

const STEP_ORIGIN: String = "origin"
const STEP_COMPUTE: String = "compute"
const STEP_OPEN_TREE: String = "open_tree"
const STEP_BUY_VECTOR: String = "buy_vector"
const STEP_SPREAD: String = "spread"
const STEP_ANOMALY: String = "anomaly"
const STEP_EVENT: String = "event"
const STEP_SITE: String = "site"
const STEP_DISCOVERED: String = "discovered"
const STEP_COUNTER_MOVE: String = "counter_move"
const STEP_DONE: String = "done"
## The order the card counts in; the first five are also the order they come in.
const STEPS: Array[String] = ["origin", "compute", "open_tree", "buy_vector", "spread",
	"anomaly", "event", "site", "discovered", "counter_move", "done"]
const LINEAR_COUNT: int = 5
## The steps that end by reading: they carry a button.
const READ_STEPS: Array[String] = ["compute", "spread", "counter_move", "done"]
## §3.4: the closing card comes this long after the discovery step ended.
const DONE_AFTER_DAYS: int = 20

const KEY_STEP: String = "UI_COACH_STEP"
const KEY_NEXT: String = "UI_COACH_NEXT"
const KEY_GO: String = "UI_COACH_GO"
const KEY_SKIP: String = "UI_COACH_SKIP"
const PLACEHOLDER_N: String = "n"
const PLACEHOLDER_TOTAL: String = "total"
## The card's width in the full layout, and the gap it keeps above the HUD.
const MAX_WIDTH: float = 440.0
const GAP: float = 12.0

## The ring the card moves; the session gives it one on its own layer.
var ring: CoachRing = null
## The HUD, for the height of what the card must sit above.
var hud: Control = null

var _step: String = ""
var _done: Dictionary[String, bool] = {}
var _queue: Array[String] = []
var _discovered_day: int = -1

var _counter: Label = null
var _title: Label = null
var _body: Label = null
var _next: ConsoleButton = null
var _skip: ConsoleButton = null


func _ready() -> void:
	theme_type_variation = &"ConsolePanelRaised"
	visible = false
	_build()
	EventBus.run_started.connect(_on_run_started)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


## The step on the card, or "".
func current_step() -> String:
	return _step


## Whether the introduction runs in this run at all: a player's run, with the
## setting on.
func active() -> bool:
	return Settings.tutorial and Game.sim != null and Game.policy == null


func _process(_delta: float) -> void:
	if not active():
		_show("")
		return
	if not _step.is_empty() and _is_finished(_step):
		_finish(_step)
	_offer_next()
	_place()
	if ring != null:
		ring.target = _target(_step)


# ----------------------------------------------------------------- the steps


## What the card points at in this step, "" for nothing.
func _target(step: String) -> String:
	match step:
		STEP_ORIGIN:
			return CoachRing.TARGET_ORIGIN_BUTTON
		STEP_COMPUTE:
			return CoachRing.TARGET_COMPUTE
		STEP_OPEN_TREE:
			return CoachRing.TARGET_CAPABILITIES
		STEP_BUY_VECTOR:
			# §3.4: with the tree closed the ring goes back to the way in.
			return CoachRing.TARGET_VECTOR if _is_open(CoachRing.TARGET_TREE) \
				else CoachRing.TARGET_CAPABILITIES
		STEP_SPREAD:
			return CoachRing.TARGET_OVERLAY
		STEP_SITE:
			return CoachRing.TARGET_SITE_PROMPT
		STEP_DISCOVERED, STEP_COUNTER_MOVE:
			return CoachRing.TARGET_CONTAINMENT
	return ""


## §3.4's *Ends when*, for the steps that do not end by a button.
func _is_finished(step: String) -> bool:
	var world: World = Game.sim.world
	match step:
		STEP_ORIGIN:
			return world.agent.origin != 0
		STEP_OPEN_TREE:
			return _is_open(CoachRing.TARGET_TREE)
		STEP_BUY_VECTOR:
			return world.modifiers.has_flag(ModifierDef.FLAG_BREAKOUT)
		STEP_ANOMALY:
			return world.anomalies.is_empty()
		STEP_EVENT:
			return world.events.is_empty()
		STEP_SITE:
			return Game.site_request == null
		STEP_DISCOVERED:
			return _is_open(CoachRing.TARGET_CONTAINMENT_PANEL)
	return false


## §3.4's *Shows when*, for the steps that wait for their moment.
func _has_come(step: String) -> bool:
	var world: World = Game.sim.world
	match step:
		STEP_ANOMALY:
			return not world.anomalies.is_empty()
		STEP_EVENT:
			return not world.events.is_empty()
		STEP_SITE:
			return Game.site_request != null \
				and Game.site_request.kind != SiteRequest.KIND_ORIGIN
		STEP_DISCOVERED:
			# After the discovery modal, not under it.
			return world.discovered and not Game.is_held()
		STEP_COUNTER_MOVE:
			for faction: Faction in world.factions:
				if not faction.preparing.is_empty():
					return true
			return false
		STEP_DONE:
			return _discovered_day >= 0 and world.day >= _discovered_day + DONE_AFTER_DAYS
	return false


## The next card, when none is up: the next of the first five in order, then the
## first waiting moment in the order of `STEPS`.
func _offer_next() -> void:
	if not _step.is_empty():
		return
	for i: int in LINEAR_COUNT:
		if not _done.has(STEPS[i]):
			_show(STEPS[i])
			return
	for i: int in range(LINEAR_COUNT, STEPS.size()):
		var step: String = STEPS[i]
		if not _done.has(step) and not _queue.has(step) and _has_come(step):
			_queue.append(step)
	if not _queue.is_empty():
		_show(_queue.pop_front())


func _finish(step: String) -> void:
	_done[step] = true
	if step == STEP_DISCOVERED:
		_discovered_day = Game.sim.world.day
	_show("")
	if step == STEP_DONE:
		Settings.set_tutorial(false)


func _show(step: String) -> void:
	if step == _step:
		return
	_step = step
	visible = not step.is_empty()
	if ring != null:
		ring.target = _target(step)
	if visible:
		_render()
		Reveal.play(self)


func _is_open(target_name: String) -> bool:
	for node: Node in get_tree().get_nodes_in_group(CoachRing.group(target_name)):
		var panel: SlidePanel = node as SlidePanel
		if panel != null:
			return panel.is_open
		var control: Control = node as Control
		if control != null and control.is_visible_in_tree():
			return true
	return false


# ---------------------------------------------------------------- the card


func _build() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"StackTight"
	add_child(column)
	_counter = CapsLabel.new()
	column.add_child(_counter)
	_title = Label.new()
	_title.theme_type_variation = &"LabelHeading"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)
	var row: HFlowContainer = HFlowContainer.new()
	row.theme_type_variation = &"FlowSnug"
	column.add_child(row)
	_next = ConsoleButton.new()
	_next.primary = true
	_next.pressed.connect(_on_next_pressed)
	row.add_child(_next)
	_skip = ConsoleButton.new()
	_skip.label_key = KEY_SKIP
	_skip.pressed.connect(_on_skip_pressed)
	row.add_child(_skip)


func _render() -> void:
	if _step.is_empty():
		return
	_counter.text = Format.caps(tr(KEY_STEP).format({
		PLACEHOLDER_N: STEPS.find(_step) + 1, PLACEHOLDER_TOTAL: STEPS.size()}))
	var key: String = "UI_COACH_%s" % _step.to_upper()
	_title.text = tr(key + "_TITLE")
	_body.text = tr(key + "_BODY")
	_next.visible = READ_STEPS.has(_step)
	_next.label_key = KEY_GO if _step == STEP_DONE else KEY_NEXT


## Bottom centre, above whatever the HUD shows at the bottom — the prompt strip
## included — and never wider than the screen allows.
func _place() -> void:
	if not visible:
		return
	var view: Vector2 = get_viewport_rect().size
	var width: float = minf(MAX_WIDTH, view.x - float(UiTokens.GUTTER) * 2.0)
	var bottom: float = GAP
	if hud != null:
		bottom += float(hud.call(&"bottom_inset"))
		var prompt: Control = CoachRing.find(get_tree(), CoachRing.TARGET_SITE_PROMPT)
		if prompt != null:
			bottom += prompt.size.y + GAP
	custom_minimum_size.x = width
	size = Vector2(width, get_combined_minimum_size().y)
	position = Vector2(floorf((view.x - width) * 0.5), view.y - bottom - size.y)


func _on_next_pressed() -> void:
	if not _step.is_empty():
		_finish(_step)


func _on_skip_pressed() -> void:
	Settings.set_tutorial(false)
	_show("")


## A new run starts the introduction from what the setting says: on means from
## the first step.
func _on_run_started(_seed_value: int) -> void:
	_done.clear()
	_queue.clear()
	_discovered_day = -1
	_show("")
