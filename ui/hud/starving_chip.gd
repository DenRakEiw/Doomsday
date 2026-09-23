class_name StarvingChip
extends RefCounted
## The one rule for the starving chip (opposition.md §9.4), which the top bar and
## the phone strip both show: visible while nothing comes in, the days left
## before Autophagy in it, `ALERT` in the last `STARVING_ALERT_DAYS` — a moment,
## the switch-off is about to happen. Never instantiated.

const KEY_STARVING: String = "UI_HUD_STARVING"
const PLACEHOLDER_DAYS: String = "days"


## A hidden chip, shaped for a bar.
static func create() -> Chip:
	var chip: Chip = Chip.new()
	chip.visible = false
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


## Shows or hides `chip` for the run as it stands.
static func apply(chip: Chip, sim: Simulation) -> void:
	if chip == null:
		return
	var left: int = sim.starving_days_left() if sim != null else -1
	chip.visible = sim != null and sim.world.starving_days > 0 and left >= 0
	if not chip.visible:
		return
	chip.set_label(KEY_STARVING, {PLACEHOLDER_DAYS: Format.number(float(left), Format.Kind.DAYS)})
	chip.kind = Chip.Kind.ALERT if left <= UiTokens.STARVING_ALERT_DAYS else Chip.Kind.DEFAULT
