extends GutTest
## `HeadlineDef` as the loader builds it (spec ticker.md §3.2): what a minimal
## entry defaults to, and that a full one arrives with every field typed.


func _load(entry: Dictionary) -> HeadlineDef:
	var db: ContentDB = Fixtures.db_with_headlines([entry])
	return db.headline(str(entry["id"]))


func test_loads_every_field_with_defaults() -> void:
	var def: HeadlineDef = _load(Fixtures.headline("h_min", HeadlineDef.STREAM_FILLER,
		{"when": {}}))
	assert_eq(def.register, HeadlineDef.REGISTER_ANY)
	assert_eq(def.weight, 1.0)
	assert_eq(def.chance, 1.0)
	assert_eq(def.cooldown_days, 0)
	assert_eq(def.max_fires, 0)
	assert_false(def.fallback)
	assert_false(def.has_event_trigger(), "a filler has no event trigger")
	assert_eq(def.key(), "HEADLINE_H_MIN")


func test_loads_every_field_as_written() -> void:
	var def: HeadlineDef = _load(Fixtures.headline("h_full", HeadlineDef.STREAM_CONSEQUENCE, {
		"register": HeadlineDef.REGISTER_EMERGENCY,
		"on": {
			"event": SimEvent.NODE_PURCHASED,
			"data": {"node": ["fx_grip", "fx_quiet"]},
			"node_tree": TechNodeDef.TREE_CAPABILITIES,
			"node_tier": 1,
		},
		"when": {"regions_min": 3, "phase": ["covert", "emergent"], "discovered": false},
		"weight": 2.5,
		"chance": 0.5,
		"cooldown_days": 12,
		"max_fires": 2,
		"fallback": true,
	}))
	assert_eq(def.register, HeadlineDef.REGISTER_EMERGENCY)
	assert_true(def.has_event_trigger())
	assert_eq(def.on_event, SimEvent.NODE_PURCHASED)
	assert_eq(def.on_data["node"], ["fx_grip", "fx_quiet"])
	assert_eq(def.on_node_tree, TechNodeDef.TREE_CAPABILITIES)
	assert_eq(def.on_node_tier, 1)
	assert_eq(def.when["regions_min"], 3.0, "numbers are cast at the boundary")
	assert_eq(def.when["phase"], ["covert", "emergent"] as Array[String])
	assert_eq(def.when["discovered"], false)
	assert_eq(def.weight, 2.5)
	assert_eq(def.chance, 0.5)
	assert_eq(def.cooldown_days, 12)
	assert_eq(def.max_fires, 2)
	assert_true(def.fallback)


## §3.2: a scalar is a one-element list, so the evaluator has one shape to read.
func test_a_scalar_data_value_becomes_a_one_element_list() -> void:
	var def: HeadlineDef = _load(Fixtures.headline("h_scalar", HeadlineDef.STREAM_CONSEQUENCE,
		{"on": {"event": SimEvent.DISCOVERED, "data": {"cause": SimEvent.CAUSE_DEATHS}}}))
	assert_eq(def.on_data["cause"], [SimEvent.CAUSE_DEATHS])


func test_the_region_filters_arrive_as_tiers() -> void:
	var def: HeadlineDef = _load(Fixtures.headline("h_region", HeadlineDef.STREAM_CONSEQUENCE, {
		"on": {
			"event": SimEvent.REGION_SEEDED,
			"region_attr_min": {"compute": 3},
			"region_attr_max": {"regulation": 1},
		},
	}))
	assert_eq(def.on_region_attr_min["compute"], 3)
	assert_eq(def.on_region_attr_max["regulation"], 1)
