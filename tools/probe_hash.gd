extends SceneTree

const Harness := preload("res://tools/sim_harness.gd")


func _init() -> void:
	var result: ContentLoadResult = ContentLoader.load_root("res://tests/fixtures/world_small")
	var problems: Array[String] = []
	var played: Dictionary = Harness.play(result.db, 1, GreedyPolicy.ID, 120, false, problems)
	var sim: Simulation = played["sim"]
	var loaded: LoadResult = WorldSerializer.from_json(WorldSerializer.to_json(sim), result.db)
	var a: String = JSON.stringify(sim.world.to_dict(), "", true, true)
	var b: String = JSON.stringify(loaded.sim.world.to_dict(), "", true, true)
	print("equal text: ", a == b, "  lengths ", a.length(), " ", b.length())
	if a != b:
		for i: int in mini(a.length(), b.length()):
			if a[i] != b[i]:
				print("first difference at ", i)
				print("  a: ...", a.substr(maxi(0, i - 60), 120))
				print("  b: ...", b.substr(maxi(0, i - 60), 120))
				break
	quit(0)
