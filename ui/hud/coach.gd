extends PanelContainer
## The guided first run (`first-run.md` §3) and the hints for what comes later
## (§6): a card that says what to do next and a ring round the control it means.
##
## The introduction's steps 1–5 come in order at the start; 6–10 each come the
## first time their moment does; 11 closes it — per run, while
## `Settings.tutorial`. The ten hints come once per profile, the first time
## their moment comes in whatever run that is (`ProfileManager.hints_seen`),
## while `Settings.hints`. One card, one ring, one queue. The card asks the run
## and the interface what is the case each frame — cheap, and nothing has to
## remember to tell it. It never holds the clock and never blocks input:
## everything it points at can be done around it.
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

# §6.3's hints, in the order of its table — urgent first, which is also the
# order several arriving in one frame queue in.
const HINT_STARVING: String = "starving"
const HINT_TASK_FORCE_SETUP: String = "task_force_setup"
const HINT_COUNTER_ARRIVED: String = "counter_arrived"
const HINT_VALUE_DRIFT: String = "value_drift"
const HINT_EMERGENT: String = "emergent"
const HINT_CHAIN: String = "chain"
const HINT_TASK_FORCE: String = "task_force"
const HINT_ABILITY: String = "ability"
const HINT_OPEN: String = "open"
const HINT_DRIFT: String = "drift"
const HINTS: Array[String] = ["starving", "task_force_setup", "counter_arrived", "value_drift",
	"emergent", "chain", "task_force", "ability", "open", "drift"]
## The cards about one open event: that event gone ends them (§6.2), step 7
## included since D6.5 narrowed it to openings.
const EVENT_CARDS: Array[String] = ["event", "counter_arrived", "value_drift", "emergent",
	"chain"]

const KEY_STEP: String = "UI_COACH_STEP"
const KEY_NEXT: String = "UI_COACH_NEXT"
const KEY_GO: String = "UI_COACH_GO"
const KEY_SKIP: String = "UI_COACH_SKIP"
const KEY_HINT: String = "UI_COACH_HINT"
const KEY_GOT_IT: String = "UI_COACH_GOT_IT"
const KEY_HINTS_OFF: String = "UI_COACH_HINTS_OFF"
const KEY_MORE: String = "UI_COACH_MORE"
const PLACEHOLDER_N: String = "n"
const PLACEHOLDER_TOTAL: String = "total"
## `_event_id` when the card is about no event (the world counts from 1).
const NO_EVENT: int = 0
## The card's width in the full layout, and the gap it keeps above the HUD.
const MAX_WIDTH: float = 440.0
const GAP: float = 12.0

## The ring the card moves; the session gives it one on its own layer.
var ring: CoachRing = null
## The HUD, for the height of what the card must sit above.
var hud: Control = null
## The session's modal host: with a modal up the card moves out of its way.
var modals: ModalHost = null

var _step: String = ""
var _done: Dictionary[String, bool] = {}
var _queue: Array[String] = []
var _discovered_day: int = -1
## The open event the card is about, remembered when it is shown (§6.2).
var _event_id: int = NO_EVENT
## The ability hint ends when an ability is used after it was shown: the
## cooldowns as they stood then.
var _cooldowns_at_show: Dictionary[String, int] = {}

var _counter: Label = null
var _title: Label = null
var _body: Label = null
var _next: ConsoleButton = null
var _more: ConsoleButton = null
var _skip: ConsoleButton = null


func _ready() -> void:
	theme_type_variation = &"ConsolePanelRaised"
	visible = false
	_build()
	EventBus.run_started.connect(_on_run_started)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


## The step or hint on the card, or "".
func current_step() -> String:
	return _step


static func is_hint(step: String) -> bool:
	return HINTS.has(step)


## Whether the coach runs in this run at all: a player's run that has not ended,
## with the introduction or the hints on (§6.2). A run that ends with a hint on
## the card records nothing — the card just goes.
func active() -> bool:
	return (Settings.tutorial or Settings.hints) and Game.sim != null and Game.policy == null \
		and Game.sim.world.outcome == World.Outcome.NONE


func _process(_delta: float) -> void:
	if not active():
		_show("")
		return
	if not _step.is_empty():
		if not _is_switched_on(_step):
			# Its setting went off while it was up: gone, and not recorded.
			_show("")
		elif _is_finished(_step):
			_finish(_step)
	_offer_next()
	# DESIGN? §6.4 leaves the card up while *More*'s page is open, but the card
	# sits on the layer above the modals and covered most of the page (at 150 %
	# text nearly all of it). Until decided, it steps aside while the Codex is
	# open — not ended, not recorded — and is back when the Codex closes.
	var covered: bool = _is_open(CoachRing.TARGET_HELP)
	visible = not _step.is_empty() and not covered
	_place()
	if ring != null:
		ring.target = "" if covered else _target(_step)


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
		STEP_DISCOVERED, STEP_COUNTER_MOVE, HINT_TASK_FORCE:
			return CoachRing.TARGET_CONTAINMENT
		HINT_STARVING:
			return CoachRing.TARGET_STARVING
		HINT_ABILITY:
			# §6.3: the region panel's actions when they are on screen, else the
			# phone's way to the picker; a desk without either names `A` in text.
			if CoachRing.find(get_tree(), CoachRing.TARGET_ACTIONS) != null:
				return CoachRing.TARGET_ACTIONS
			return CoachRing.TARGET_ABILITIES
		HINT_OPEN:
			return CoachRing.TARGET_CAPABILITIES
		HINT_DRIFT:
			return CoachRing.TARGET_DRIFT
	return ""


## §3.4's and §6.3's *Ends when*, besides the card's own button.
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
		STEP_EVENT, HINT_COUNTER_ARRIVED, HINT_VALUE_DRIFT, HINT_EMERGENT, HINT_CHAIN:
			return world.event_by_id(_event_id) == null
		STEP_SITE:
			return Game.site_request == null
		STEP_DISCOVERED, HINT_TASK_FORCE:
			return _is_open(CoachRing.TARGET_CONTAINMENT_PANEL)
		HINT_STARVING:
			return world.starving_days == 0
		HINT_TASK_FORCE_SETUP:
			return world.task_force.state != TaskForce.STATE_SETUP
		HINT_ABILITY:
			return _ability_used()
	return false


## §3.4's *Shows when*, for the steps that wait for their moment, and §6.3's for
## the hints.
func _has_come(step: String) -> bool:
	var world: World = Game.sim.world
	match step:
		STEP_ANOMALY:
			return not world.anomalies.is_empty()
		STEP_EVENT, HINT_COUNTER_ARRIVED, HINT_VALUE_DRIFT, HINT_EMERGENT, HINT_CHAIN:
			return _event_for(step) != NO_EVENT
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
		HINT_STARVING:
			# The starving chip's own rule.
			return world.starving_days > 0
		HINT_TASK_FORCE_SETUP:
			return world.task_force.state == TaskForce.STATE_SETUP
		HINT_TASK_FORCE:
			return world.task_force.is_present()
		HINT_ABILITY:
			# The Actions row's reveal (loop-mechanics §16.8).
			for def: AbilityDef in Game.sim.db.abilities:
				if Game.sim.ability_level(def.id) > 0:
					return true
			return false
		HINT_OPEN:
			return world.phase == World.Phase.OPEN
		HINT_DRIFT:
			return DriftChip.shows(Game.sim)
	return false


## The first open event the card `step` would be about, or `NO_EVENT`.
func _event_for(step: String) -> int:
	for event: OpenEvent in Game.sim.world.events:
		var def: EventDef = Game.sim.db.event(event.def)
		if def != null and _is_about(step, def):
			return event.id
	return NO_EVENT


## §6.3: the kinds, and the emergent kind split by data — the Value Drift card is
## the one whose `when` names a drift threshold (`DriftChip.mark`'s rule), never
## told apart by its id.
static func _is_about(step: String, def: EventDef) -> bool:
	var names_drift: bool = def.when.has(DriftChip.KEY_DRIFT_MIN)
	match step:
		STEP_EVENT:
			return def.kind == EventDef.KIND_OPENING
		HINT_COUNTER_ARRIVED:
			return def.kind == EventDef.KIND_COUNTER_MOVE
		HINT_VALUE_DRIFT:
			return def.kind == EventDef.KIND_EMERGENT and names_drift
		HINT_EMERGENT:
			return def.kind == EventDef.KIND_EMERGENT and not names_drift
		HINT_CHAIN:
			return def.kind == EventDef.KIND_CHAIN
	return false


## An ability used since the hint was shown: a cooldown that is new or runs
## later than it did then.
func _ability_used() -> bool:
	var cooldowns: Dictionary[String, int] = Game.sim.world.agent.cooldowns
	for id: String in cooldowns:
		if not _cooldowns_at_show.has(id) or cooldowns[id] > _cooldowns_at_show[id]:
			return true
	return false


## Whether the setting that owns `step` is on.
static func _is_switched_on(step: String) -> bool:
	return Settings.hints if is_hint(step) else Settings.tutorial


## §6.2: hints are offered once the origin is chosen, and while the
## introduction runs only after its step 5.
func _hints_offered() -> bool:
	if not Settings.hints or Game.sim.world.agent.origin == 0:
		return false
	return not Settings.tutorial or _done.has(STEP_SPREAD)


## Whether a queued card has gone stale by its turn (§6.2): a hint whose moment
## has passed is dropped unseen and comes again the next time. The
## introduction's own steps keep their place, as they always did.
func _is_stale(step: String) -> bool:
	if not is_hint(step):
		return not Settings.tutorial
	return not _hints_offered() or ProfileManager.has_seen_hint(step) or not _has_come(step)


## The next card, when none is up: the next of the first five in order, then the
## first waiting moment in the order of `STEPS` and then of `HINTS`.
func _offer_next() -> void:
	if not _step.is_empty():
		return
	if Settings.tutorial:
		for i: int in LINEAR_COUNT:
			if not _done.has(STEPS[i]):
				_show(STEPS[i])
				return
		for i: int in range(LINEAR_COUNT, STEPS.size()):
			var step: String = STEPS[i]
			if not _done.has(step) and not _queue.has(step) and _has_come(step):
				_queue.append(step)
	if _hints_offered():
		for hint: String in HINTS:
			if not ProfileManager.has_seen_hint(hint) and not _queue.has(hint) \
					and _has_come(hint):
				_queue.append(hint)
	while not _queue.is_empty():
		var next: String = _queue.pop_front()
		if not _is_stale(next):
			_show(next)
			return


## A card ends: a step is done for this run, a hint for the profile — whichever
## way it ended (§6.2).
func _finish(step: String) -> void:
	if is_hint(step):
		ProfileManager.mark_hint_seen(step)
		_show("")
		return
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
	_event_id = NO_EVENT
	if EVENT_CARDS.has(step):
		_event_id = _event_for(step)
	if step == HINT_ABILITY:
		_cooldowns_at_show = Game.sim.world.agent.cooldowns.duplicate()
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
	# Three buttons wrap on a phone (§6.4).
	var row: HFlowContainer = HFlowContainer.new()
	row.theme_type_variation = &"FlowSnug"
	column.add_child(row)
	_next = ConsoleButton.new()
	_next.primary = true
	_next.pressed.connect(_on_next_pressed)
	row.add_child(_next)
	_more = ConsoleButton.new()
	_more.label_key = KEY_MORE
	_more.pressed.connect(_on_more_pressed)
	row.add_child(_more)
	_skip = ConsoleButton.new()
	_skip.label_key = KEY_SKIP
	_skip.pressed.connect(_on_skip_pressed)
	row.add_child(_skip)


func _render() -> void:
	if _step.is_empty():
		return
	if is_hint(_step):
		# §6.4: a hint says so instead of counting, and can always be put away.
		_counter.text = Format.caps(tr(KEY_HINT))
		_next.visible = true
		_next.label_key = KEY_GOT_IT
		_skip.label_key = KEY_HINTS_OFF
	else:
		_counter.text = Format.caps(tr(KEY_STEP).format({
			PLACEHOLDER_N: STEPS.find(_step) + 1, PLACEHOLDER_TOTAL: STEPS.size()}))
		_next.visible = READ_STEPS.has(_step)
		_next.label_key = KEY_GO if _step == STEP_DONE else KEY_NEXT
		_skip.label_key = KEY_SKIP
	_more.visible = not HelpPages.page_for_step(_step).is_empty()
	var key: String = "UI_COACH_%s" % _step.to_upper()
	_title.text = tr(key + "_TITLE")
	_body.text = tr(key + "_BODY")


## The card as it reads now, for the tests: the caps line, and whether each of
## the three buttons shows.
func caps_text() -> String:
	return _counter.text


func more_button() -> ConsoleButton:
	return _more


func next_button() -> ConsoleButton:
	return _next


func skip_button() -> ConsoleButton:
	return _skip


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
	var left: float = floorf((view.x - width) * 0.5)
	# DESIGN? At the bottom centre the card covered a wire card's answers (a
	# hint about that very card, §6.2). With a modal up on a wide screen it goes
	# to the bottom left, clear of the centred modal; a phone has no room aside.
	if modals != null and modals.is_open() and view.x >= float(UiTokens.COMPACT_WIDTH):
		left = float(UiTokens.GUTTER)
	# A long hint at 150 % text on a phone is taller than the room above the
	# strip: then it keeps its top on screen and runs down over the strip.
	position = Vector2(left, maxf(GAP, view.y - bottom - size.y))


func _on_next_pressed() -> void:
	if not _step.is_empty():
		_finish(_step)


## §6.4: *More* opens the Codex on the card's page and leaves the card up.
func _on_more_pressed() -> void:
	var page: String = HelpPages.page_for_step(_step)
	if not page.is_empty():
		EventBus.help_requested.emit(page)


## *End the introduction* on a step; *No more hints* on a hint, which records
## nothing (§6.2).
func _on_skip_pressed() -> void:
	if is_hint(_step):
		Settings.set_hints(false)
	else:
		Settings.set_tutorial(false)
	_show("")


## A new run starts the introduction from what the setting says: on means from
## the first step. The hints seen are the profile's and stay.
func _on_run_started(_seed_value: int) -> void:
	_done.clear()
	_queue.clear()
	_discovered_day = -1
	_show("")
