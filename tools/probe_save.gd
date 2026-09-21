extends SceneTree

const Harness := preload("res://tools/sim_harness.gd")


func _init() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://tests/fixtures/world_small")
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(result.db, 1, GreedyPolicy.ID, 120, false, problems)
	var sim: Simulation = played["sim"]
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), result.db)
	print("ok=", loaded.ok(), " reason=", loaded.reason)
	var before: Dictionary = sim.world.to_dict()
	var after: Dictionary = loaded.sim.world.to_dict()
	_diff("", before, after)
	quit(0)


func _diff(path: String, a: Variant, b: Variant) -> void:
	if typeof(a) != typeof(b):
		print("TYPE ", path, ": ", type_string(typeof(a)), " vs ", type_string(typeof(b)))
		return
	if typeof(a) == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db2: Dictionary = b
		for k: Variant in da.keys():
			if not db2.has(k):
				print("MISSING ", path, "/", k)
				continue
			_diff("%s/%s" % [path, k], da[k], db2[k])
		return
	if typeof(a) == TYPE_ARRAY:
		var aa: Array = a
		var ba: Array = b
		if aa.size() != ba.size():
			print("SIZE ", path, ": ", aa.size(), " vs ", ba.size())
			return
		for i: int in aa.size():
			_diff("%s[%d]" % [path, i], aa[i], ba[i])
		return
	if a != b:
		if typeof(a) == TYPE_FLOAT:
			print("VALUE ", path, ": ", String.num(a, 17), " vs ", String.num(b, 17))
		else:
			print("VALUE ", path, ": ", a, " vs ", b)
