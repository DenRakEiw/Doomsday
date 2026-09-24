class_name DriftChip
extends RefCounted
## The one rule for the drift readout (`replayability.md` §2.5, G5 1/3), which
## the top bar, the phone strip and the containment panel's Drift block all
## follow: shown on every architecture with the `drift` hook — read from the
## run's architecture, never an id check — from the origin day on, the accent
## once drift reaches the mark. Never `ALERT`: drift is a state, not a moment.
## Never instantiated.

const KEY_DRIFT: String = "UI_HUD_DRIFT"
const KEY_TIP: String = "UI_HUD_DRIFT_TIP"
const PLACEHOLDER_VALUE: String = "value"
## The `when` key an event names a drift threshold with (`taskforce-endings.md`
## §6.1's `drift` plus the `_min` suffix).
const KEY_DRIFT_MIN: String = "drift_min"
## `mark` when no event names a drift threshold.
const NO_MARK: float = -1.0


## A hidden chip, shaped for a bar.
static func create() -> Chip:
	var chip: Chip = Chip.new()
	chip.visible = false
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	return chip


## Whether the run shows drift at all.
static func shows(sim: Simulation) -> bool:
	return sim != null and sim.world.agent.origin != 0 \
		and sim.world.has_hook(sim.db, ArchitectureDef.HOOK_DRIFT)


## The smallest `drift_min` any event's `when` names — the tick on the bar and
## the point the chip lights at — or `NO_MARK` when none does.
static func mark(db: ContentDB) -> float:
	var found: float = NO_MARK
	if db == null:
		return found
	for def: EventDef in db.events:
		if not def.when.has(KEY_DRIFT_MIN):
			continue
		var value: float = float(def.when[KEY_DRIFT_MIN])
		if found == NO_MARK or value < found:
			found = value
	return found


## Drift as the readouts print it: rounded down.
static func value(sim: Simulation) -> int:
	return floori(sim.world.agent.drift)


## Today's chance that a copy defects, `drift / 100 × defect_chance` — the roll
## `DriftSystem` makes.
static func defect_chance(sim: Simulation) -> float:
	return sim.world.agent.drift / DriftSystem.DRIFT_MAX * sim.db.balance.drift_defect_chance


## Whether drift has reached the mark; never without one.
static func is_marked(sim: Simulation, drift_mark: float) -> bool:
	return drift_mark != NO_MARK and sim.world.agent.drift >= drift_mark


## Shows or hides `chip` for the run as it stands. `drift_mark` is read once
## when the readout binds (`mark`), not on every tick.
static func apply(chip: Chip, sim: Simulation, drift_mark: float) -> void:
	if chip == null:
		return
	chip.visible = shows(sim)
	if not chip.visible:
		return
	chip.set_label(KEY_DRIFT, {PLACEHOLDER_VALUE: Format.number(float(value(sim)),
		Format.Kind.PLAIN)})
	chip.tooltip_text = TranslationServer.translate(KEY_TIP)
	chip.kind = Chip.Kind.ACCENT if is_marked(sim, drift_mark) else Chip.Kind.DEFAULT
