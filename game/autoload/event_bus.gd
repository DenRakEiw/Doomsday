extends Node
## The one place the interface listens (spec ui-foundation.md §10.1).
##
## `core/` has no signals — it has the event outbox — so `Game` drains that
## outbox and every `CommandResult` onto these signals, in the order the
## simulation produced them. Nothing here holds state: a second source of truth
## next to the `World` is exactly what this architecture is avoiding.
##
## An autoload, so no `class_name`: the autoload name is the global.

signal run_started(seed_value: int)
## `World.OUTCOME_IDS[outcome]`, never the enum value.
signal run_ended(outcome: String)
signal tick_advanced(day: int)
## Every event, tick and command, in order.
signal sim_event(event: SimEvent)
signal command_applied(command: Command, result: CommandResult)
## 0, 1, 2 or 4.
signal speed_changed(speed: int)
## Region index; 0 means none.
signal region_hovered(index: int)
signal region_selected(index: int)
signal overlay_changed(mode: int)
signal locale_changed(locale: String)
signal reduced_motion_changed(enabled: bool)
signal tree_pauses_changed(enabled: bool)
## Whether the interface is holding the clock (m3-screens §10.2). The speed group
## and the paused badge read it; the speed itself is still `speed_changed`.
signal hold_changed(held: bool)
