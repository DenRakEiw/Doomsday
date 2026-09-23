extends PanelContainer
## The numbers a run is judged by (spec ui-foundation.md §5.3): penetration,
## footprint and harm — and, from Covert on, the threat (opposition.md §9.1):
## the daily discovery risk until they know, the leading faction after.
##
## Penetration is a share and fills the bar honestly. Footprint and harm have no
## natural maximum — they are stats, not percentages — so the bar fills against a
## presentation maximum (`UiTokens`) while the label reads the raw number.
##
## Scene-specific, so no `class_name`.

const KEY_PENETRATION: String = "UI_TERM_PENETRATION"
const KEY_FOOTPRINT: String = "UI_TERM_FOOTPRINT"
const KEY_HARM: String = "UI_TERM_HARM"
const KEY_RISK: String = "UI_TERM_RISK"
const KEY_RATE: String = "UI_CONTAINMENT_RATE"
const PLACEHOLDER_RATE: String = "rate"
const PREFIX_FACTION: String = "FACTION_"

## §5.7: three bars side by side, or stacked in their compact form.
var compact: bool = false:
	set(value):
		if value == compact and is_node_ready():
			return
		compact = value
		if is_node_ready():
			_apply_compact()

@onready var _row: HBoxContainer = %Row
@onready var _column: VBoxContainer = %Column
@onready var _penetration: StatBar = %Penetration
@onready var _footprint: StatBar = %Footprint
@onready var _harm: StatBar = %Harm
@onready var _threat: StatBar = %Threat

## The faction the threat bar shows, "" for the risk face.
var _leader: String = ""


func _ready() -> void:
	_apply_compact()
	EventBus.run_started.connect(_on_run_started)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.command_applied.connect(_on_command_applied)
	EventBus.sim_event.connect(_on_sim_event)
	refresh()


## Re-reads the run. A purchase moves footprint and harm between two ticks, so
## this is called after a command as well as after a day.
## m3-screens §6.1: Footprint appears with the Covert phase, Harm the moment
## there is any. A hidden bar takes no space, and the rest share the row.
func apply_reveal(phase: World.Phase, harm: float) -> void:
	_show(_footprint, phase >= World.Phase.COVERT)
	_show(_harm, phase >= World.Phase.EMERGENT or (phase >= World.Phase.COVERT and harm > 0.0))
	_show(_threat, phase >= World.Phase.COVERT)


## Revealing is not just `visible`: the block fades in and its border flashes, so
## the player sees that the interface grew rather than that it jumped (§6.1).
func _show(bar: StatBar, shown: bool) -> void:
	if bar.visible == shown:
		return
	bar.visible = shown
	if not shown:
		return
	Reveal.play(bar)


func refresh() -> void:
	var world: World = Game.sim.world if Game.sim != null else null
	if world == null or Game.db == null:
		_penetration.set_value(0.0)
		_footprint.set_value_raw(0.0, 0.0, Format.Kind.PLAIN)
		_harm.set_value_raw(0.0, 0.0, Format.Kind.PLAIN)
		_apply_risk_face(0.0)
		return
	_penetration.set_value(world.infected_share(Game.db))
	var footprint: float = world.footprint()
	_footprint.set_value_raw(footprint / UiTokens.FOOTPRINT_BAR_MAX, footprint,
		Format.Kind.PLAIN)
	# §6.1: the maximum over regions, because half the Harm nodes are scoped.
	var harm: float = world.max_harm()
	_harm.set_value_raw(harm / UiTokens.HARM_BAR_MAX, harm, Format.Kind.PLAIN)
	_apply_threat(world)


## The two faces of §9.1, computed from state so a load is right at once.
func _apply_threat(world: World) -> void:
	var leader: String = Game.sim.threat_leader()
	if leader.is_empty():
		var risk: float = float(Game.sim.discovery_risk()[ContainmentSystem.RISK_TOTAL])
		_apply_risk_face(risk)
		return
	if leader != _leader:
		_leader = leader
		_threat.theme_type_variation = UiTokens.stat_bar_variation(leader)
		_threat.label_key = PREFIX_FACTION + leader.to_upper()
		_threat.set_glyph(Glyphs.faction(leader), UiTokens.FACTION_TOKENS[leader],
			UiTokens.FACTION_GLYPH)
		var marks: Array[float] = Game.db.balance.containment_thresholds.duplicate()
		marks.append(1.0)
		_threat.ticks = marks
	var faction: Faction = world.faction(leader)
	_threat.set_value_raw(faction.containment, faction.containment, Format.Kind.PERCENT)
	_threat.set_delta_in(KEY_RATE, PLACEHOLDER_RATE,
		float(Game.containment_rates.get(leader, 0.0)), Format.Kind.PERCENT)


func _apply_risk_face(risk: float) -> void:
	if not _leader.is_empty() or _threat.theme_type_variation != UiTokens.STAT_BAR_RISK:
		_leader = ""
		_threat.theme_type_variation = UiTokens.STAT_BAR_RISK
		_threat.label_key = KEY_RISK
		_threat.clear_glyph()
		_threat.clear_delta()
		var none: Array[float] = []
		_threat.ticks = none
	_threat.set_value_raw(risk / UiTokens.RISK_BAR_MAX, risk, Format.Kind.PERCENT_FINE)


func _apply_compact() -> void:
	_row.visible = not compact
	_column.visible = compact
	var parent: Container = (_column as Container) if compact else (_row as Container)
	for bar: StatBar in [_penetration, _footprint, _harm, _threat]:
		_move(bar, parent)
		bar.compact = compact
		bar.size_flags_horizontal = int(Control.SIZE_FILL) if compact \
			else int(Control.SIZE_EXPAND_FILL)
		bar.size_flags_stretch_ratio = 1.0
	custom_minimum_size.y = float(UiTokens.STAT_ROW_COMPACT_HEIGHT if compact
		else UiTokens.STAT_ROW_HEIGHT)


func _move(node: Control, parent: Container) -> void:
	if node.get_parent() == parent:
		parent.move_child(node, parent.get_child_count() - 1)
		return
	node.get_parent().remove_child(node)
	parent.add_child(node)


func _on_run_started(_seed_value: int) -> void:
	refresh()


func _on_tick_advanced(_day: int) -> void:
	refresh()


func _on_command_applied(_command: Command, _result: CommandResult) -> void:
	refresh()


## §9.1: a new leader is a moment — the swap already happened in `refresh`, the
## number lights up once more so the eye goes there.
func _on_sim_event(event: SimEvent) -> void:
	if event.type == SimEvent.THREAT_LEADER_CHANGED:
		refresh()
		_threat.flash()
