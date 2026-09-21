extends SceneTree


func _init() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var bad_str_to_var: int = 0
	var bad_bytes: int = 0
	var bad_num_scientific: int = 0
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	for i: int in 20000:
		var v: float = rng.randf() / float(rng.randi_range(1, 1000))
		var text: String = String.num(v, 17 - int(floor(log(absf(v)) / log(10.0))))
		if str_to_var(text) != v:
			bad_str_to_var += 1
		if str_to_var(String.num_scientific(v)) != v:
			bad_num_scientific += 1
		bytes.encode_double(0, v)
		var restored: PackedByteArray = PackedByteArray()
		restored.resize(8)
		restored.encode_s64(0, bytes.decode_s64(0))
		if restored.decode_double(0) != v:
			bad_bytes += 1
	print("str_to_var(String.num):        ", bad_str_to_var, " of 20000 lossy")
	print("str_to_var(num_scientific):    ", bad_num_scientific, " of 20000 lossy")
	print("PackedByteArray double<->s64:  ", bad_bytes, " of 20000 lossy")
	quit(0)
