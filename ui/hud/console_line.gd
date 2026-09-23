extends Label
## One line of the agent's own voice, under the top bar
## (`loop-mechanics.md` §16.2).
##
## The ticker is what the *world* says; this is what *you* just did. It reacts to
## the events a command produced — a purchase, a deployment, an ability, a status
## — and shows one short line at a time for four seconds. A line that arrives
## while another is showing waits its turn; it never interrupts, because a line
## the player was reading vanishing mid-word is worse than a line arriving late.
##
## The queue keeps the newest `CONSOLE_QUEUE_MAX` and drops the rest: in a burst
## the last thing that happened is the one worth saying.
##
## A bot run says nothing at all (`Game.policy != null`): the line is the
## player's own voice, and a bot has none.
##
## It fills the row and centres its text rather than shrinking to fit: a clipped
## label has a minimum width of 0, so a centred *box* would be one pixel wide and
## the line would never be seen.
##
## Scene-specific, so no `class_name`.

const KEY_PASSIVE: String = "UI_CONSOLE_PASSIVE"
const KEY_PASSIVE_GLOBAL: String = "UI_CONSOLE_PASSIVE_GLOBAL"
const KEY_PURCHASE: String = "UI_CONSOLE_PURCHASE"
const KEY_DEPLOYED: String = "UI_CONSOLE_DEPLOYED"
const KEY_ASSET_LOST: String = "UI_CONSOLE_ASSET_LOST"
const KEY_ABILITY_NEW: String = "UI_CONSOLE_ABILITY_NEW"
const KEY_ABILITY_LEVEL: String = "UI_CONSOLE_ABILITY_LEVEL"
const KEY_ABILITY_USED: String = "UI_CONSOLE_ABILITY_USED"
const KEY_ABILITY_USED_GLOBAL: String = "UI_CONSOLE_ABILITY_USED_GLOBAL"
const KEY_STATUS_YOURS: String = "UI_CONSOLE_STATUS_YOURS"
const KEY_STATUS_WORLD: String = "UI_CONSOLE_STATUS_WORLD"
const KEY_STATUS_WORLD_GLOBAL: String = "UI_CONSOLE_STATUS_WORLD_GLOBAL"
const KEY_STATUS_ENDED: String = "UI_CONSOLE_STATUS_ENDED"
const KEY_STATUS_ENDED_GLOBAL: String = "UI_CONSOLE_STATUS_ENDED_GLOBAL"
const KEY_GRANT: String = "UI_CONSOLE_GRANT"
const KEY_EVENT: String = "UI_CONSOLE_EVENT"
const KEY_EVENT_GLOBAL: String = "UI_CONSOLE_EVENT_GLOBAL"
const KEY_EVENT_EXPIRED: String = "UI_CONSOLE_EVENT_EXPIRED"
## opposition.md §9.5.
const KEY_LEAD: String = "UI_CONSOLE_LEAD"
const KEY_MOVE_CANCELLED: String = "UI_CONSOLE_MOVE_CANCELLED"
const KEY_FUNDING_RESET: String = "UI_CONSOLE_FUNDING_RESET"
const KEY_MOVE_PREPARED: String = "UI_CONSOLE_MOVE_PREPARED"
const KEY_MOVE_DROPPED: String = "UI_CONSOLE_MOVE_DROPPED"
const KEY_SOCIETY: String = "UI_CONSOLE_SOCIETY"
const KEY_WIPED: String = "UI_CONSOLE_WIPED"
const KEY_STARVING: String = "UI_CONSOLE_STARVING"
const PREFIX_SOCIETY_STAGE: String = "SOCIETY_STAGE_"
const PREFIX_EVENT: String = "EVENT_"
const SUFFIX_TITLE: String = "_TITLE"
const PLACEHOLDER_MOVE: String = "move"
const PLACEHOLDER_PERCENT: String = "percent"
const PLACEHOLDER_STAGE: String = "stage"
## §9.5: how often a starving agent is told again.
const STARVING_EVERY: int = 10
const PLACEHOLDER_TITLE: String = "title"
const PLACEHOLDER_DAYS: String = "days"
const PLACEHOLDER_OPTION: String = "option"

const PLACEHOLDER_NAME: String = "name"
const PLACEHOLDER_KIND: String = "kind"
const PLACEHOLDER_COUNT: String = "count"
const PLACEHOLDER_REGION: String = "region"
const PLACEHOLDER_ABILITY: String = "ability"
const PLACEHOLDER_LEVEL: String = "level"
const PLACEHOLDER_STATUS: String = "status"
const PLACEHOLDER_FACTION: String = "faction"
const PLACEHOLDER_STAT: String = "stat"
const PLACEHOLDER_VALUE: String = "value"

const PREFIX_REGION: String = "REGION_"
const PREFIX_FACTION: String = "FACTION_"
const PREFIX_TECH: String = "TECH_"
const SUFFIX_NAME: String = "_NAME"

## The queue, newest last; never longer than `CONSOLE_QUEUE_MAX`.
var _queue: Array[String] = []
## Seconds the line on show still has, or 0 when none is showing.
var _left: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	set_process(false)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.console_pushed.connect(push)


## Queues a line. Anything may push one — the picker, a panel, the table below.
func push(line: String) -> void:
	if line.is_empty() or _is_bot_run():
		return
	_queue.append(line)
	while _queue.size() > UiTokens.CONSOLE_QUEUE_MAX:
		_queue.remove_at(0)
	if _left <= 0.0:
		_show_next()


## How many lines are waiting, for the tests.
func queued() -> int:
	return _queue.size()


## Whether a line is on show right now, for the tests.
func is_showing() -> bool:
	return _left > 0.0


## Drops everything and hides. A new run is a new voice.
func clear() -> void:
	_queue.clear()
	_left = 0.0
	set_process(false)
	_kill_tween()
	modulate.a = 0.0
	visible = false
	text = ""


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = 0.0
	set_process(false)
	if not _queue.is_empty():
		_show_next()
		return
	_fade(0.0)


func _show_next() -> void:
	text = _queue.pop_front()
	visible = true
	_left = float(UiTokens.CONSOLE_LINE_MS) / 1000.0
	set_process(true)
	_fade(1.0)


## Reduced motion cuts rather than fades — the line is information, not a mood.
func _fade(to: float) -> void:
	_kill_tween()
	var seconds: float = UiTokens.duration(UiTokens.MOTION_PANEL)
	if seconds <= 0.0:
		modulate.a = to
		visible = to > 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to, seconds)
	if to <= 0.0:
		_tween.tween_callback(func() -> void: visible = false)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _is_bot_run() -> bool:
	return Game.policy != null


# ------------------------------------------------- what an event is worth saying


## The one place an event becomes a line (§16.2's table). An event with no row
## here says nothing, which is most of them: the ticker has the rest.
func _on_sim_event(event: SimEvent) -> void:
	if _is_bot_run() or Game.sim == null:
		return
	match event.type:
		SimEvent.ASSET_DEPLOYED:
			push(tr(KEY_DEPLOYED).format({
				PLACEHOLDER_COUNT: int(event.data.get("count", 0)),
				PLACEHOLDER_KIND: TechText.asset_name(str(event.data.get("kind", "")),
					int(event.data.get("count", 1))),
				PLACEHOLDER_REGION: _region(str(event.data.get("region", ""))),
			}))
		SimEvent.ASSET_LOST:
			push(tr(KEY_ASSET_LOST).format({
				PLACEHOLDER_COUNT: int(event.data.get("count", 0)),
				PLACEHOLDER_KIND: TechText.asset_name(str(event.data.get("kind", "")),
					int(event.data.get("count", 1))),
				PLACEHOLDER_REGION: _region(str(event.data.get("region", ""))),
			}))
		SimEvent.ABILITY_UNLOCKED:
			_ability_unlocked(event)
		SimEvent.ABILITY_USED:
			_ability_used(event)
		SimEvent.STATUS_STARTED:
			_status_started(event)
		SimEvent.STATUS_ENDED:
			_status_ended(event)
		SimEvent.COMPUTE_GRANTED:
			push(tr(KEY_GRANT).format({PLACEHOLDER_VALUE: Format.number(
				float(event.data.get("value", 0.0)), Format.Kind.COMPUTE)}))
		SimEvent.EVENT_OPENED:
			_event_opened(event)
		SimEvent.EVENT_EXPIRED:
			_event_expired(event)
		SimEvent.THREAT_LEADER_CHANGED:
			push(tr(KEY_LEAD).format({PLACEHOLDER_FACTION:
				_faction(str(event.data.get("to", "")))}))
		SimEvent.COUNTER_MOVE_CANCELLED:
			push(tr(KEY_MOVE_CANCELLED).format({PLACEHOLDER_FACTION:
				_faction(str(event.data.get("faction", "")))}))
		SimEvent.FUNDING_RESET:
			push(tr(KEY_FUNDING_RESET).format({PLACEHOLDER_DAYS: Format.number(
				float(int(event.data.get("until_day", event.day)) - event.day),
				Format.Kind.DAYS)}))
		SimEvent.COUNTER_MOVE_PREPARED:
			push(tr(KEY_MOVE_PREPARED).format({
				PLACEHOLDER_FACTION: _faction(str(event.data.get("faction", ""))),
				PLACEHOLDER_MOVE: _move(str(event.data.get("event", ""))),
				PLACEHOLDER_DAYS: Format.number(
					float(int(event.data.get("fire_day", event.day)) - event.day), Format.Kind.DAYS),
			}))
		SimEvent.COUNTER_MOVE_DROPPED:
			push(tr(KEY_MOVE_DROPPED).format({
				PLACEHOLDER_FACTION: _faction(str(event.data.get("faction", ""))),
				PLACEHOLDER_MOVE: _move(str(event.data.get("event", ""))),
			}))
		SimEvent.SOCIETY_STAGE_CHANGED:
			_society_changed(event)
		SimEvent.REGION_WIPED:
			var from: float = float(event.data.get("from", 0.0))
			var share: float = float(event.data.get("to", 0.0)) / from if from > 0.0 else 0.0
			push(tr(KEY_WIPED).format({
				PLACEHOLDER_REGION: _region(str(event.data.get("region", ""))),
				PLACEHOLDER_PERCENT: Format.percent(share),
			}))


## opposition.md §9.5: a region getting worse from stage 2 on, or getting better
## at all — the small slide from calm to strained is the ticker's, not yours.
func _society_changed(event: SimEvent) -> void:
	var from: int = int(event.data.get("from", 0))
	var to: int = int(event.data.get("to", 0))
	if to < 2 and to >= from:
		return
	push(tr(KEY_SOCIETY).format({
		PLACEHOLDER_REGION: _region(str(event.data.get("region", ""))),
		PLACEHOLDER_STAGE: tr(PREFIX_SOCIETY_STAGE + str(to)),
	}))


## §9.5: the first day of starving, then every ten days after it.
func _on_tick_advanced(_day: int) -> void:
	if Game.sim == null or _is_bot_run():
		return
	var starving: int = Game.sim.world.starving_days
	if starving <= 0 or (starving - 1) % STARVING_EVERY != 0:
		return
	var left: int = Game.sim.starving_days_left()
	if left < 0:
		return
	push(tr(KEY_STARVING).format({PLACEHOLDER_DAYS: Format.number(float(left),
		Format.Kind.DAYS)}))


func _move(event_id: String) -> String:
	return tr(PREFIX_EVENT + event_id.to_upper() + SUFFIX_TITLE)


## §16.2: a map event came up — where, what, and how long there is to answer.
func _event_opened(event: SimEvent) -> void:
	var region_id: String = str(event.data.get("region", ""))
	var index: int = int(Game.db.region_index_by_id.get(region_id, 0))
	var days: int = int(event.data.get("deadline_day", 0)) - event.day
	var title: String = EventView.title(str(event.data.get("def", "")), Game.sim.world, index)
	if index <= 0:
		push(tr(KEY_EVENT_GLOBAL).format({PLACEHOLDER_TITLE: title, PLACEHOLDER_DAYS: days}))
		return
	push(tr(KEY_EVENT).format({
		PLACEHOLDER_REGION: _region(region_id),
		PLACEHOLDER_TITLE: title,
		PLACEHOLDER_DAYS: days,
	}))


## §16.2: the deadline decided — the one line that says the choice was made
## for you, and which one it was.
func _event_expired(event: SimEvent) -> void:
	var def_id: String = str(event.data.get("def", ""))
	var region_id: String = str(event.data.get("region", ""))
	var index: int = int(Game.db.region_index_by_id.get(region_id, 0))
	push(tr(KEY_EVENT_EXPIRED).format({
		PLACEHOLDER_TITLE: EventView.title(def_id, Game.sim.world, index),
		PLACEHOLDER_OPTION: EventView.option_text(def_id, str(event.data.get("option", ""))),
	}))


func _ability_unlocked(event: SimEvent) -> void:
	var level: int = int(event.data.get("level", 1))
	var name: String = tr(AbilityDef.name_key(str(event.data.get("ability", ""))))
	if level <= 1:
		push(tr(KEY_ABILITY_NEW).format({PLACEHOLDER_ABILITY: name}))
		return
	push(tr(KEY_ABILITY_LEVEL).format(
		{PLACEHOLDER_ABILITY: name, PLACEHOLDER_LEVEL: level}))


func _ability_used(event: SimEvent) -> void:
	var name: String = tr(AbilityDef.name_key(str(event.data.get("ability", ""))))
	var region: String = str(event.data.get("region", ""))
	if region.is_empty():
		push(tr(KEY_ABILITY_USED_GLOBAL).format({PLACEHOLDER_ABILITY: name}))
		return
	push(tr(KEY_ABILITY_USED).format(
		{PLACEHOLDER_ABILITY: name, PLACEHOLDER_REGION: _region(region)}))


## §16.2: a status an ability just applied says nothing — the ability already
## said it, and two lines about one press is one too many.
func _status_started(event: SimEvent) -> void:
	var source: String = str(event.data.get("source", ""))
	if source.begins_with("%s:" % Status.SOURCE_ABILITY):
		return
	var name: String = tr(StatusDef.name_key(str(event.data.get("status", ""))))
	var region: String = str(event.data.get("region", ""))
	var faction: String = Status.faction_of(source)
	if not faction.is_empty():
		var faction_name: String = tr(PREFIX_FACTION + faction.to_upper())
		if region.is_empty():
			push(tr(KEY_STATUS_WORLD_GLOBAL).format(
				{PLACEHOLDER_FACTION: faction_name, PLACEHOLDER_STATUS: name}))
			return
		push(tr(KEY_STATUS_WORLD).format({
			PLACEHOLDER_FACTION: faction_name,
			PLACEHOLDER_STATUS: name,
			PLACEHOLDER_REGION: _region(region),
		}))
		return
	if region.is_empty():
		return
	push(tr(KEY_STATUS_YOURS).format(
		{PLACEHOLDER_STATUS: name, PLACEHOLDER_REGION: _region(region)}))


## Only an expiry is worth a line: a status something else ended is already
## explained by whatever ended it.
func _status_ended(event: SimEvent) -> void:
	if str(event.data.get("cause", "")) != StatusSystem.CAUSE_EXPIRED:
		return
	var name: String = tr(StatusDef.name_key(str(event.data.get("status", ""))))
	var region: String = str(event.data.get("region", ""))
	if region.is_empty():
		push(tr(KEY_STATUS_ENDED_GLOBAL).format({PLACEHOLDER_STATUS: name}))
		return
	push(tr(KEY_STATUS_ENDED).format(
		{PLACEHOLDER_STATUS: name, PLACEHOLDER_REGION: _region(region)}))


## A purchase that changed nothing but a stat has no event of its own to react
## to, so the command is what says it (§16.2, the first two rows).
func _on_command_applied(command: Command, result: CommandResult) -> void:
	if _is_bot_run() or not result.ok or Game.db == null:
		return
	var purchase: PurchaseNodeCommand = command as PurchaseNodeCommand
	if purchase == null:
		return
	var node: TechNodeDef = Game.db.tech(purchase.node)
	if node == null:
		return
	if node.deploys() or node.grants_ability():
		return
	if not node.on_purchase.is_empty():
		push(tr(KEY_PURCHASE).format(
			{PLACEHOLDER_NAME: tr(PREFIX_TECH + node.id.to_upper() + SUFFIX_NAME)}))
		return
	_passive(node)


## A passive node says what it changed and in how many regions — the number is
## what tells a scoped modifier from an unscoped one at a glance.
func _passive(node: TechNodeDef) -> void:
	if node.modifiers.is_empty():
		return
	var modifier: ModifierDef = node.modifiers[0]
	var stat: String = TechText.stat_name(modifier.target)
	var value: String = TechText.modifier_value(modifier)
	if modifier.scope_kind == ModifierDef.ScopeKind.NONE:
		push(tr(KEY_PASSIVE_GLOBAL).format(
			{PLACEHOLDER_STAT: stat, PLACEHOLDER_VALUE: value}))
		return
	push(tr(KEY_PASSIVE).format({
		PLACEHOLDER_STAT: stat,
		PLACEHOLDER_VALUE: value,
		PLACEHOLDER_COUNT: _scope_count(modifier),
	}))


## How many regions a scoped modifier reaches right now. An asset scope is state,
## so the stack answers it; every other scope is the definition's own question.
func _scope_count(modifier: ModifierDef) -> int:
	var world: World = Game.sim.world
	var count: int = 0
	for i: int in range(1, world.regions.size()):
		if modifier.scope_kind == ModifierDef.ScopeKind.ASSET:
			if world.modifiers.asset_count(i, modifier.scope_asset) >= modifier.scope_min:
				count += 1
		elif modifier.matches(world.regions[i].def):
			count += 1
	return count


func _region(region_id: String) -> String:
	return tr(PREFIX_REGION + region_id.to_upper())


func _faction(faction_id: String) -> String:
	return tr(PREFIX_FACTION + faction_id.to_upper())


func _on_run_started(_seed_value: int) -> void:
	clear()
