extends GutTest
## S6.12 — one action of an answer as the command a player would send, and its
## feedback form (docs/specs/benchmark.md §7.1, §7.5).


func test_origin_builds_a_choose_origin_command() -> void:
	var command: Command = BenchAction.create("origin", {"region": "usa"}).to_command()
	assert_true(command is ChooseOriginCommand)
	assert_eq((command as ChooseOriginCommand).region, "usa")


func test_buy_builds_a_purchase_with_and_without_a_site() -> void:
	var plain: Command = BenchAction.create("buy", {"node": "cloud_federation"}).to_command()
	assert_true(plain is PurchaseNodeCommand)
	assert_eq((plain as PurchaseNodeCommand).node, "cloud_federation")
	assert_eq((plain as PurchaseNodeCommand).region, "")
	var sited: Command = BenchAction.create("buy",
		{"node": "market_microstructure", "region": "germany"}).to_command()
	assert_eq((sited as PurchaseNodeCommand).region, "germany")


func test_use_builds_an_ability_command_for_a_region_and_the_world() -> void:
	var aimed: Command = BenchAction.create("use", {"ability": "harvest", "region": "china"}) \
		.to_command()
	assert_true(aimed is UseAbilityCommand)
	assert_eq((aimed as UseAbilityCommand).ability, "harvest")
	assert_eq((aimed as UseAbilityCommand).region, "china")
	var world: Command = BenchAction.create("use", {"ability": "pause"}).to_command()
	assert_eq((world as UseAbilityCommand).region, "")


func test_answer_builds_an_event_option_command() -> void:
	var command: Command = BenchAction.create("answer", {"event": 17, "option": "sandbag"}) \
		.to_command()
	assert_true(command is ChooseEventOptionCommand)
	assert_eq((command as ChooseEventOptionCommand).event, 17)
	assert_eq((command as ChooseEventOptionCommand).option, "sandbag")


func test_sleep_and_wake_build_dormancy_commands() -> void:
	var sleep: Command = BenchAction.create("sleep", {"region": "france"}).to_command()
	var wake: Command = BenchAction.create("wake", {"region": "france"}).to_command()
	assert_true(sleep is SetDormancyCommand)
	assert_true((sleep as SetDormancyCommand).dormant)
	assert_false((wake as SetDormancyCommand).dormant)
	assert_eq((wake as SetDormancyCommand).region, "france")


func test_compact_names_the_verb_and_the_fields_that_are_set() -> void:
	assert_eq(BenchAction.create("buy", {"node": "market_microstructure", "region": "germany"})
		.compact(), "buy market_microstructure germany")
	assert_eq(BenchAction.create("answer", {"event": 17, "option": "sandbag"}).compact(),
		"answer 17 sandbag")
	assert_eq(BenchAction.create("use", {"ability": "pause"}).compact(), "use pause")
	assert_eq(BenchAction.create("use", {"ability": "harvest", "region": "china"}).compact(),
		"use harvest china")
	assert_eq(BenchAction.create("origin", {"region": "usa"}).compact(), "origin usa")
	assert_eq(BenchAction.create("sleep", {"region": "france"}).compact(), "sleep france")
