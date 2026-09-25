class_name TaskForceRules
extends RefCounted
## Where the Task Force goes and what it does there (`taskforce-endings.md` §2–§3).
## Pure: no RNG, no state of its own — the same world always gets the same answer,
## which is also what keeps these rules replaceable by a player in Containment
## mode (`scenarios.md` §0).

## The action statuses the team does not return to while one runs (§2.1).
const STATUS_PREFIX: String = "tf_"
const TARGET_CAPACITY: String = "containment_capacity"


## §2.1: infected, not dark, not dormant (unless marked, §14), not hidden
## (capacity 0), and no action of the team's still running there.
static func eligible(world: World, db: ContentDB, index: int) -> bool:
	if index <= 0 or index >= world.regions.size():
		return false
	var region: Region = world.regions[index]
	if region.dark or region.penetration <= 0.0:
		return false
	if region.dormant and dormancy_hides(world, index):
		return false
	if world.modifiers.value(TARGET_CAPACITY, region.def) <= 0.0:
		return false
	for action: TaskForceActionDef in db.task_force_actions:
		if world.status_in_region(action.status, index) != null:
			return false
	return true


## §14: whether a dormant region is hidden from the team — false while it is
## marked. The one place the rule is asked: `eligible`, `fizzle_cause` and the
## bots use it.
static func dormancy_hides(world: World, index: int) -> bool:
	return not world.task_force.is_marked(index, world.day)


## §1.4's fizzle causes, in the order they are asked: "" when the target still
## stands.
static func fizzle_cause(world: World, db: ContentDB, index: int) -> String:
	var region: Region = world.regions[index]
	if region.dark:
		return SimEvent.CAUSE_DARK
	if region.dormant and dormancy_hides(world, index):
		return TaskForceSystem.CAUSE_DORMANT
	if region.penetration <= 0.0:
		return TaskForceSystem.CAUSE_CLEAN
	if world.modifiers.value(TARGET_CAPACITY, region.def) <= 0.0:
		return TaskForceSystem.CAUSE_HIDDEN
	return ""


## §2.2: the best target from where the team stands, or 0. Ties to the lower index.
static func choose_target(sim: Simulation) -> int:
	var world: World = sim.world
	var hops: PackedInt32Array = distances(world, world.task_force.region)
	var best: int = 0
	var best_score: float = -1.0
	for i: int in range(1, world.regions.size()):
		if not eligible(world, sim.db, i):
			continue
		var region: Region = world.regions[i]
		var value: float = sim.hardware(i) + float(region.asset_count(AssetDef.KIND_LAB)) \
			+ float(region.asset_count(AssetDef.KIND_FLEET))
		var distance: int = hops[i] if hops[i] >= 0 else world.regions.size()
		var score: float = value * region.penetration * (1.0 + region.control) \
			/ (1.0 + sim.db.balance.task_force_distance_penalty * float(distance))
		if score > best_score:
			best_score = score
			best = i
	return best


## The next region on a shortest path by link count from `from` to `to` — every
## link, closed ones included (it travels with authority). Ties go to the
## neighbour with the lower index. `to` itself when it is next door; `from` when
## there is no way.
static func next_hop(world: World, from: int, to: int) -> int:
	if from == to:
		return to
	var back: PackedInt32Array = distances(world, to)
	var best: int = from
	var best_distance: int = -1
	for neighbour: int in neighbours(world, from):
		var distance: int = back[neighbour]
		if distance < 0:
			continue
		if best_distance < 0 or distance < best_distance \
				or (distance == best_distance and neighbour < best):
			best_distance = distance
			best = neighbour
	return best


## Link count from `origin` to every region; -1 where there is no way.
static func distances(world: World, origin: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	out.resize(world.regions.size())
	out.fill(-1)
	if origin <= 0 or origin >= world.regions.size():
		return out
	out[origin] = 0
	# Every region's `neighbours` in one pass over the links rather than one pass
	# per region reached (S6.11): the same sorted lists, so the same search.
	var adjacency: Array[Array] = _adjacency(world)
	var queue: Array[int] = [origin]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for neighbour: int in adjacency[at]:
			if out[neighbour] >= 0:
				continue
			out[neighbour] = out[at] + 1
			queue.append(neighbour)
	return out


## Every region one link away, ascending, whatever the link's state.
static func neighbours(world: World, index: int) -> Array[int]:
	var out: Array[int] = []
	for link: Link in world.links:
		var other: int = 0
		if link.def.a == index:
			other = link.def.b
		elif link.def.b == index:
			other = link.def.a
		if other > 0 and not out.has(other):
			out.append(other)
	out.sort()
	return out


## §3: the first action whose level and rule hold for the target, or null.
## `neighbours(world, i)` for every region index at once.
static func _adjacency(world: World) -> Array[Array]:
	var lists: Array[Array] = []
	for i: int in world.regions.size():
		var empty: Array[int] = []
		lists.append(empty)
	for link: Link in world.links:
		var a: int = link.def.a
		var b: int = link.def.b
		if b > 0 and a >= 0 and a < lists.size() and not lists[a].has(b):
			lists[a].append(b)
		if a > 0 and b >= 0 and b < lists.size() and not lists[b].has(a):
			lists[b].append(a)
	for list: Array in lists:
		list.sort()
	return lists


static func action_for(world: World, db: ContentDB, index: int) -> TaskForceActionDef:
	for action: TaskForceActionDef in db.task_force_actions:
		if world.task_force.level < action.level_min:
			continue
		if action.rule == null or action.rule.check(world, index).is_empty():
			return action
	return null
