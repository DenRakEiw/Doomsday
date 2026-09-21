class_name SimSystem
extends RefCounted
## One step of a tick. Systems are stateless: everything that must survive a
## tick lives in `World`.
##
## The order the systems run in is fixed in `Simulation` and is part of the
## determinism contract; changing it is a recorded decision, not a refactor.


## Appends whatever happened to `events`. The base does nothing, which is what
## makes an empty simulation tick.
@warning_ignore("unused_parameter")
func tick(world: World, db: ContentDB, events: Array[SimEvent]) -> void:
	pass
