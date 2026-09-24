class_name CodexTracker
extends Node
## What a run adds to the Codex (spec `screens-full.md` §5.1).
##
## Presentation, owned by the session, never in `core/`: it listens to
## `EventBus`, collects ids into a per-run set, and merges the set into the
## profile when the run ends and on every autosave — so a crash loses at most
## a week. A bot's run collects nothing.
##
## Architectures and endings are not collected: the first derive from the
## profile's counters, the second are the profile's `endings_seen`.

const TAB_REGIONS: String = "regions"
const TAB_FACTIONS: String = "factions"
const TAB_TECH: String = "tech"
const TAB_CHARACTERS: String = "characters"
const TAB_STATUSES: String = "statuses"
## §6.1: a faction's entry lists its counter-moves once each has been seen.
const TAB_MOVES: String = "moves"
const TABS: Array[String] = [TAB_REGIONS, TAB_FACTIONS, TAB_TECH, TAB_CHARACTERS, TAB_STATUSES,
	TAB_MOVES]

## §5.1: the chain step that introduces each character.
const CHARACTER_BY_EVENT: Dictionary[String, String] = {
	"rs_preprint": "researcher",
	"op_contact": "operator",
	"si_emergence": "instance",
	"ch_offer": "child",
	"br_split": "child",
}
const CHARACTER_TASK_FORCE: String = "task_force"
const CHARACTERS: Array[String] = ["researcher", "operator", "instance", "child", "task_force"]

const FIELD_REGION: String = "region"
const FIELD_NODE: String = "node"
const FIELD_STATUS: String = "status"
const FIELD_DEF: String = "def"
const FIELD_KIND: String = "kind"

## Tab → the ids this run has met, each once, in the order they came.
var collected: Dictionary[String, Array] = {}

## Tab → what the profile knew when the run started. The autosave merges as the
## run goes, so "new" is measured against the start, not the profile now.
var _known: Dictionary[String, Array] = {}


func _init() -> void:
	clear()


func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.sim_event.connect(_on_sim_event)
	# `Game.apply` announces a command before its events, and the session's
	# autosave answers the announcement: the tracker takes the events first, so
	# that the save's merge already has them.
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.tick_advanced.connect(_on_tick_advanced)


func clear() -> void:
	collected.clear()
	_known.clear()
	for tab: String in TABS:
		collected[tab] = []
		_known[tab] = (ProfileManager.codex.get(tab, []) as Array).duplicate()


## Adds `id` to `tab` once.
func add(tab: String, id: String) -> void:
	if id.is_empty() or not collected.has(tab):
		return
	var ids: Array = collected[tab]
	if not ids.has(id):
		ids.append(id)


## How many of the collected ids the profile did not have when the run started
## (§7: `UI_RESULT_CODEX_NEW`).
func new_count() -> int:
	var count: int = 0
	for tab: String in TABS:
		var known: Array = _known[tab]
		for id: Variant in collected[tab]:
			if not known.has(id):
				count += 1
	return count


## Writes the run's set into the profile. Nothing on a bot's run.
func merge() -> void:
	if Game.policy != null:
		return
	for tab: String in TABS:
		var ids: Array[String] = []
		for id: Variant in collected[tab]:
			ids.append(str(id))
		if not ids.is_empty():
			ProfileManager.merge_codex(tab, ids)


## Everything the world already shows — a loaded run brings its past with it.
func sweep(world: World, db: ContentDB) -> void:
	for i: int in range(1, world.regions.size()):
		if world.regions[i].seeded_day >= 0:
			add(TAB_REGIONS, world.regions[i].def.id)
	for node_id: String in world.agent.owned_nodes:
		add(TAB_TECH, node_id)
	_sweep_factions(world)
	for status: Status in world.statuses:
		add(TAB_STATUSES, status.id)
	if db != null and world.task_force.is_present():
		add(TAB_CHARACTERS, CHARACTER_TASK_FORCE)


## §5.1: one event, the tab it opens.
func take(event: SimEvent) -> void:
	match event.type:
		SimEvent.ORIGIN_CHOSEN, SimEvent.REGION_SEEDED:
			add(TAB_REGIONS, str(event.data.get(FIELD_REGION, "")))
		SimEvent.NODE_PURCHASED:
			add(TAB_TECH, str(event.data.get(FIELD_NODE, "")))
		SimEvent.STATUS_STARTED:
			add(TAB_STATUSES, str(event.data.get(FIELD_STATUS, "")))
		SimEvent.EVENT_OPENED:
			var def_id: String = str(event.data.get(FIELD_DEF, ""))
			add(TAB_CHARACTERS, CHARACTER_BY_EVENT.get(def_id, ""))
			if str(event.data.get(FIELD_KIND, "")) == EventDef.KIND_COUNTER_MOVE:
				add(TAB_MOVES, def_id)
		SimEvent.TASK_FORCE_APPEARED:
			add(TAB_CHARACTERS, CHARACTER_TASK_FORCE)


func _sweep_factions(world: World) -> void:
	for faction: Faction in world.factions:
		if faction.containment > 0.0:
			add(TAB_FACTIONS, faction.id)


func _on_run_started(_seed_value: int) -> void:
	clear()
	if Game.sim != null and Game.policy == null:
		sweep(Game.sim.world, Game.sim.db)


func _on_command_applied(_command: Command, result: CommandResult) -> void:
	if Game.policy != null:
		return
	for event: SimEvent in result.events:
		take(event)


func _on_sim_event(event: SimEvent) -> void:
	if Game.policy == null:
		take(event)


## §5.1: a faction is met when its containment first rises above 0.
func _on_tick_advanced(_day: int) -> void:
	if Game.sim != null and Game.policy == null:
		_sweep_factions(Game.sim.world)
