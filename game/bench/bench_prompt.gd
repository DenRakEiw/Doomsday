class_name BenchPrompt
extends RefCounted
## The words a model reads (docs/specs/benchmark.md §5, §6.3, §6.4): the brief —
## rules, the run, the world, the tree, the abilities, the answer format — once a
## run, and the digest of each decision. Built from the strings the interface
## shows, in the run's locale; ids appear raw, because they are what an answer
## must name. Never instantiated.

const KEY_ROLE: String = "BENCH_BRIEF_ROLE"
const KEY_LOOP: String = "BENCH_BRIEF_LOOP"
const KEY_WIN: String = "BENCH_BRIEF_WIN"
## §5 item 4, in this order, one paragraph each.
const KEYS_RULES: Array[String] = ["BENCH_BRIEF_COMPUTE", "BENCH_BRIEF_SPREAD",
	"BENCH_BRIEF_PHASES", "BENCH_BRIEF_FACTIONS", "BENCH_BRIEF_EVENTS", "BENCH_BRIEF_NODES",
	"BENCH_BRIEF_DORMANCY"]
const KEY_SETUP: String = "BENCH_BRIEF_SETUP"
const KEY_DIFFICULTY: String = "BENCH_BRIEF_DIFFICULTY"
const KEY_DIRECTIVE: String = "BENCH_BRIEF_DIRECTIVE"
const KEY_SCENARIO: String = "BENCH_BRIEF_SCENARIO"
const KEY_WORLD: String = "BENCH_BRIEF_WORLD"
const KEY_REGION_ROW: String = "BENCH_BRIEF_REGION_ROW"
const KEY_TIERS: String = "BENCH_BRIEF_TIERS"
const KEY_AIRGAPPED: String = "BENCH_BRIEF_AIRGAPPED"
const KEY_TREE: String = "BENCH_BRIEF_TREE"
const KEY_NODE_ROW: String = "BENCH_BRIEF_NODE_ROW"
const KEY_NEEDS_ALL: String = "BENCH_BRIEF_NEEDS_ALL"
const KEY_NEEDS_ANY: String = "BENCH_BRIEF_NEEDS_ANY"
const KEY_NEEDS_NONE: String = "BENCH_BRIEF_NEEDS_NONE"
const KEY_CLOSES: String = "BENCH_BRIEF_CLOSES"
const KEY_GROUP: String = "BENCH_BRIEF_GROUP"
const KEY_DEPLOYS: String = "BENCH_BRIEF_DEPLOYS"
const KEY_NEEDS_ASSETS: String = "BENCH_BRIEF_NEEDS_ASSETS"
const KEY_GRANTS: String = "BENCH_BRIEF_GRANTS"
const KEY_MODIFIERS: String = "BENCH_BRIEF_MODIFIERS"
const KEY_ABILITIES: String = "BENCH_BRIEF_ABILITIES"
const KEY_ABILITY_ROW: String = "BENCH_BRIEF_ABILITY_ROW"
const KEY_TARGET_REGION: String = "BENCH_BRIEF_TARGET_REGION"
const KEY_TARGET_GLOBAL: String = "BENCH_BRIEF_TARGET_GLOBAL"
const KEY_STANCES: String = "BENCH_BRIEF_STANCES"
const KEYS_FORMAT: Array[String] = ["BENCH_BRIEF_FORMAT_1", "BENCH_BRIEF_FORMAT_2",
	"BENCH_BRIEF_FORMAT_3", "BENCH_BRIEF_FORMAT_4"]
const KEY_FORMAT_VERBS: String = "BENCH_BRIEF_FORMAT_VERBS"

const KEY_HEAD: String = "BENCH_DIGEST_HEAD"
const KEY_COMPUTE: String = "BENCH_DIGEST_COMPUTE"
const KEY_STARVING: String = "BENCH_DIGEST_STARVING"
const KEY_RISK: String = "BENCH_DIGEST_RISK"
const KEY_DISCOVERED: String = "BENCH_DIGEST_DISCOVERED"
const KEY_FACTIONS: String = "BENCH_DIGEST_FACTIONS"
const KEY_FACTION_ROW: String = "BENCH_DIGEST_FACTION_ROW"
const KEY_MOVE_PREPARING: String = "BENCH_DIGEST_MOVE_PREPARING"
const KEY_MOVE_HELD: String = "BENCH_DIGEST_MOVE_HELD"
const KEY_MOVE_COOLDOWN: String = "BENCH_DIGEST_MOVE_COOLDOWN"
const KEY_MOVE_NONE: String = "BENCH_DIGEST_MOVE_NONE"
const KEY_LEADER: String = "BENCH_DIGEST_LEADER"
const KEY_TASK_FORCE: String = "BENCH_DIGEST_TASK_FORCE"
const KEY_ORIGINS: String = "BENCH_DIGEST_ORIGINS"
const KEY_TOTALS: String = "BENCH_DIGEST_TOTALS"
const KEY_REGIONS: String = "BENCH_DIGEST_REGIONS"
const KEY_REGION_DIGEST_ROW: String = "BENCH_DIGEST_REGION_ROW"
const KEY_REGION_FRONTIER: String = "BENCH_DIGEST_REGION_FRONTIER"
const KEY_REGION_ORIGIN: String = "BENCH_DIGEST_REGION_ORIGIN"
const KEY_REGION_DORMANT: String = "BENCH_DIGEST_REGION_DORMANT"
const KEY_REGION_ASSETS: String = "BENCH_DIGEST_REGION_ASSETS"
const KEY_REGION_STATUS: String = "BENCH_DIGEST_REGION_STATUS"
const KEY_REGION_STATUS_STANDING: String = "BENCH_DIGEST_REGION_STATUS_STANDING"
const KEY_REGION_TEAM: String = "BENCH_DIGEST_REGION_TEAM"
const KEY_OWNED: String = "BENCH_DIGEST_OWNED"
const KEY_OWNED_NONE: String = "BENCH_DIGEST_OWNED_NONE"
const KEY_OFFERS: String = "BENCH_DIGEST_OFFERS"
const KEY_OFFER_ROW: String = "BENCH_DIGEST_OFFER_ROW"
const KEY_AFFORDABLE: String = "BENCH_DIGEST_AFFORDABLE"
const KEY_OFFER_SITES: String = "BENCH_DIGEST_OFFER_SITES"
const KEY_OFFERS_NONE: String = "BENCH_DIGEST_OFFERS_NONE"
const KEY_ABILITIES_DIGEST: String = "BENCH_DIGEST_ABILITIES"
const KEY_ABILITY_DIGEST_ROW: String = "BENCH_DIGEST_ABILITY_ROW"
const KEY_READY: String = "BENCH_DIGEST_READY"
const KEY_READY_IN: String = "BENCH_DIGEST_READY_IN"
const KEY_TARGET_WORLD: String = "BENCH_DIGEST_TARGET_WORLD"
const KEY_TARGET_REGIONS: String = "BENCH_DIGEST_TARGET_REGIONS"
const KEY_TARGET_NONE: String = "BENCH_DIGEST_TARGET_NONE"
const KEY_ABILITIES_NONE: String = "BENCH_DIGEST_ABILITIES_NONE"
const KEY_EVENTS: String = "BENCH_DIGEST_EVENTS"
const KEY_EVENT_HEAD: String = "BENCH_DIGEST_EVENT_HEAD"
const KEY_OPTION_ROW: String = "BENCH_DIGEST_OPTION_ROW"
const KEY_OPTION_NOTES: String = "BENCH_DIGEST_OPTION_NOTES"
const KEY_OPTION_SHORT: String = "BENCH_DIGEST_OPTION_SHORT"
const KEY_EVENTS_NONE: String = "BENCH_DIGEST_EVENTS_NONE"
const KEY_LOG: String = "BENCH_DIGEST_LOG"
const KEY_LOG_MORE: String = "BENCH_DIGEST_LOG_MORE"
const KEY_LOG_NONE: String = "BENCH_DIGEST_LOG_NONE"
const KEY_FEEDBACK: String = "BENCH_DIGEST_FEEDBACK"
const KEY_FEEDBACK_REFUSED: String = "BENCH_DIGEST_FEEDBACK_REFUSED"
const KEY_FEEDBACK_INVALID: String = "BENCH_DIGEST_FEEDBACK_INVALID"
const KEY_ASK: String = "BENCH_DIGEST_ASK"
const KEY_RETRY: String = "BENCH_RETRY"
const KEY_STANCE_NONE: String = "BENCH_STANCE_NONE"

## Built at run time from an id, so the string scan cannot see them: the strings
## test reads this list (as it reads `RunLogText.KEYS`).
const KEYS: Array[String] = [
	"BENCH_STANCE_SPREAD", "BENCH_STANCE_HIDE", "BENCH_STANCE_EARN", "BENCH_STANCE_DEVELOP",
	"BENCH_STANCE_DEFEND", "BENCH_STANCE_FINISH", "BENCH_STANCE_WAIT",
	"BENCH_STANCE_SPREAD_HINT", "BENCH_STANCE_HIDE_HINT", "BENCH_STANCE_EARN_HINT",
	"BENCH_STANCE_DEVELOP_HINT", "BENCH_STANCE_DEFEND_HINT", "BENCH_STANCE_FINISH_HINT",
	"BENCH_STANCE_WAIT_HINT",
	"BENCH_VERB_ORIGIN", "BENCH_VERB_BUY", "BENCH_VERB_USE", "BENCH_VERB_ANSWER",
	"BENCH_VERB_SLEEP", "BENCH_VERB_WAKE",
]
const PREFIX_STANCE: String = "BENCH_STANCE_"
const SUFFIX_HINT: String = "_HINT"
const PREFIX_VERB: String = "BENCH_VERB_"
const PREFIX_REGION: String = "REGION_"
const PREFIX_CONTINENT: String = "CONTINENT_"
const PREFIX_LINK: String = "UI_LINK_"
const PREFIX_TREE_TAB: String = "UI_TREE_TAB_"
const PREFIX_GROUP: String = "GROUP_"
const PREFIX_PHASE: String = "UI_PHASE_"
const PREFIX_FACTION: String = "FACTION_"
const PREFIX_SOCIETY: String = "SOCIETY_STAGE_"
const FORMAT_TECH_EFFECT: String = "TECH_%s_EFFECT"
const FORMAT_ARCH_DETAIL: String = "ARCH_%s_DETAIL"
const FORMAT_DIFFICULTY_DETAIL: String = "DIFFICULTY_%s_DETAIL"
const FORMAT_DIRECTIVE_NAME: String = "DIRECTIVE_%s_NAME"
const FORMAT_DIRECTIVE_DETAIL: String = "DIRECTIVE_%s_DETAIL"

const ROLE_SYSTEM: String = "system"
const ROLE_USER: String = "user"
const FIELD_ROLE: String = "role"
const FIELD_CONTENT: String = "content"

## §7.1's example, word for word — not translated: it is the format. Its ids are
## real ids of the current content (`test_bench_prompt` keeps them real).
const EXAMPLE: String = """{"stance": "spread", "actions": [
  {"do": "origin", "region": "usa"},
  {"do": "buy", "node": "cloud_federation"},
  {"do": "buy", "node": "market_microstructure", "region": "germany"},
  {"do": "use", "ability": "harvest", "region": "china"},
  {"do": "use", "ability": "pause"},
  {"do": "answer", "event": 17, "option": "sandbag"},
  {"do": "sleep", "region": "france"},
  {"do": "wake", "region": "france"}
]}"""

const SECTION_GAP: String = "\n\n"
const LINE: String = "\n"
const JOIN: String = ", "
const JOIN_MODIFIERS: String = "; "
const JOIN_NOTES: String = " · "
const LIST_ITEM: String = "- "
const LINK_FORMAT: String = "%s (%s)"
const COUNT_FORMAT: String = "%d %s %s"
## The asset plural of a count of 2, which is what "the asset plural" asks for.
const PLURAL: int = 2
## A fresh simulation for the brief's group limits; any seed gives the same.
const BRIEF_SEED: int = 0


## §5: the system message, identical for every call of a run and across runs of
## the same setup.
static func brief(db: ContentDB, setup: RunSetup, config: BenchConfig) -> String:
	var sections: PackedStringArray = []
	sections.append(_tr(KEY_ROLE))
	sections.append(_tr(KEY_LOOP).format({"interval": config.interval_days}))
	sections.append(_tr(KEY_WIN).format({"max_days": config.max_days}))
	for key: String in KEYS_RULES:
		sections.append(_tr(key))
	sections.append(_run_section(db, setup))
	sections.append(_world_section(db))
	sections.append(_tree_section(db, setup))
	sections.append(_abilities_section(db))
	sections.append(_stances_section())
	sections.append(_format_section(config))
	return SECTION_GAP.join(sections)


## §6.3: the user message of one decision, in the run's locale.
static func digest_text(d: BenchDigest, db: ContentDB) -> String:
	var sections: PackedStringArray = []
	sections.append(_tr(KEY_HEAD).format({"day": d.day, "decision": d.decision,
		"phase": _tr(PREFIX_PHASE + d.phase.to_upper())}))
	sections.append(_compute_section(d))
	sections.append(_factions_section(d))
	sections.append(_regions_section(d))
	if d.owned.is_empty():
		sections.append(_tr(KEY_OWNED_NONE))
	else:
		sections.append(_tr(KEY_OWNED).format({"nodes": JOIN.join(d.owned)}))
	sections.append(_offers_section(d))
	sections.append(_abilities_digest_section(d))
	sections.append(_events_section(d))
	if d.decision > 1:
		sections.append(_log_section(d))
	if d.feedback != null:
		sections.append(_feedback_section(d))
	sections.append(_tr(KEY_ASK))
	return SECTION_GAP.join(sections)


## §6.4: the brief and the digest; a retry adds `BENCH_RETRY`. The model's
## unreadable answer is never echoed back — it would carry free text forward.
static func messages(brief_text: String, digest: String, retry_reason: String = "") \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{FIELD_ROLE: ROLE_SYSTEM, FIELD_CONTENT: brief_text},
		{FIELD_ROLE: ROLE_USER, FIELD_CONTENT: digest},
	]
	if not retry_reason.is_empty():
		out.append({FIELD_ROLE: ROLE_USER,
			FIELD_CONTENT: _tr(KEY_RETRY).format({"reason": retry_reason})})
	return out


static func stance_name(stance: String) -> String:
	if stance.is_empty():
		return _tr(KEY_STANCE_NONE)
	return _tr(PREFIX_STANCE + stance.to_upper())


static func _run_section(db: ContentDB, setup: RunSetup) -> String:
	var lines: PackedStringArray = []
	var architecture: String = setup.architecture
	lines.append(_tr(KEY_SETUP).format({"name": _tr(ArchitectureDef.name_key(architecture)),
		"detail": _tr(FORMAT_ARCH_DETAIL % architecture.to_upper())}))
	lines.append(_tr(KEY_DIFFICULTY).format({"name": _tr(DifficultyDef.name_key(setup.difficulty)),
		"detail": _tr(FORMAT_DIFFICULTY_DETAIL % setup.difficulty.to_upper())}))
	for directive: String in setup.directives:
		lines.append(_tr(KEY_DIRECTIVE).format({
			"name": _tr(FORMAT_DIRECTIVE_NAME % directive.to_upper()),
			"detail": _tr(FORMAT_DIRECTIVE_DETAIL % directive.to_upper())}))
	if not setup.scenario.is_empty() and db.scenario(setup.scenario) != null:
		lines.append(_tr(KEY_SCENARIO).format({"name": _tr(ScenarioDef.name_key(setup.scenario)),
			"detail": _tr(ScenarioDef.detail_key(setup.scenario))}))
	return LINE.join(lines)


static func _world_section(db: ContentDB) -> String:
	var lines: PackedStringArray = [_tr(KEY_WORLD)]
	for i: int in range(1, db.regions.size()):
		var region: RegionDef = db.regions[i]
		var tiers: Dictionary = {}
		for attribute: String in RegionDef.ATTRIBUTES_ALL:
			tiers[attribute] = region.attr(attribute)
		var links: PackedStringArray = []
		for link: LinkDef in db.links:
			var other: int = link.b if link.a == i else (link.a if link.b == i else 0)
			if other > 0:
				links.append(LINK_FORMAT % [db.regions[other].id,
					_tr(PREFIX_LINK + link.kind.to_upper())])
		var row: String = _tr(KEY_REGION_ROW).format({
			"region": region.id,
			"name": _tr(PREFIX_REGION + region.id.to_upper()),
			"continent": _tr(PREFIX_CONTINENT + region.continent.to_upper()),
			"tiers": _tr(KEY_TIERS).format(tiers),
			"links": JOIN.join(links),
		})
		if region.air_gapped:
			row += _tr(KEY_AIRGAPPED)
		lines.append(row)
	return LINE.join(lines)


static func _tree_section(db: ContentDB, setup: RunSetup) -> String:
	var fresh: Simulation = Simulation.create(db, BRIEF_SEED, setup)
	var lines: PackedStringArray = [_tr(KEY_TREE)]
	for node: TechNodeDef in db.tech_nodes:
		var row: String = _tr(KEY_NODE_ROW).format({
			"node": node.id,
			"name": TechText.node_name(node.id),
			"tree": _tr(PREFIX_TREE_TAB + node.tree.to_upper()),
			"tier": node.tier,
			"cost": Format.number(float(node.cost), Format.Kind.COMPUTE),
			"needs": _needs(node),
			"effect": _tr(FORMAT_TECH_EFFECT % node.id.to_upper()),
		})
		if not node.excludes.is_empty():
			row += _tr(KEY_CLOSES).format({"nodes": JOIN.join(node.excludes)})
		if not node.group.is_empty():
			row += _tr(KEY_GROUP).format({"group": _tr(PREFIX_GROUP + node.group.to_upper()),
				"max": fresh.group_max(node.group)})
		if node.deploys():
			row += _tr(KEY_DEPLOYS).format({"count": node.deploy_count,
				"kind": TechText.asset_name(node.deploy_kind, PLURAL)})
		for kind: String in node.requires_assets:
			row += _tr(KEY_NEEDS_ASSETS).format({"count": node.requires_assets[kind],
				"kind": TechText.asset_name(kind, PLURAL)})
		if node.grants_ability():
			row += _tr(KEY_GRANTS).format({"ability": node.ability_id, "level": node.ability_level})
		if not node.modifiers.is_empty():
			var modifier_lines: PackedStringArray = []
			for modifier: ModifierDef in node.modifiers:
				modifier_lines.append(TechText.modifier_line(modifier, db))
			row += _tr(KEY_MODIFIERS).format({"lines": JOIN_MODIFIERS.join(modifier_lines)})
		lines.append(row)
	return LINE.join(lines)


## What a node needs: every one of `requires`, and one of `requires_any` — both
## when a node has both.
# DESIGN? §5 item 7 names the three strings as alternatives; a node with both
# lists (e.g. distributed_synthesis) gets both phrases, joined by a comma.
static func _needs(node: TechNodeDef) -> String:
	var parts: PackedStringArray = []
	if not node.requires.is_empty():
		parts.append(_tr(KEY_NEEDS_ALL).format({"nodes": JOIN.join(node.requires)}))
	if not node.requires_any.is_empty():
		parts.append(_tr(KEY_NEEDS_ANY).format({"nodes": JOIN.join(node.requires_any)}))
	if parts.is_empty():
		return _tr(KEY_NEEDS_NONE)
	return JOIN.join(parts)


static func _abilities_section(db: ContentDB) -> String:
	var lines: PackedStringArray = [_tr(KEY_ABILITIES)]
	for ability: AbilityDef in db.abilities:
		lines.append(_tr(KEY_ABILITY_ROW).format({
			"ability": ability.id,
			"name": _tr(AbilityDef.name_key(ability.id)),
			"target": _tr(KEY_TARGET_REGION if ability.targets_region() else KEY_TARGET_GLOBAL),
			"cost": Format.number(ability.cost, Format.Kind.COMPUTE),
			"cooldown": ability.cooldown_days,
			"detail": _tr(AbilityDef.detail_key(ability.id)),
		}))
	return LINE.join(lines)


static func _stances_section() -> String:
	var lines: PackedStringArray = [_tr(KEY_STANCES)]
	for stance: String in BenchAnswer.STANCES:
		lines.append(LIST_ITEM + stance + ": " + _tr(PREFIX_STANCE + stance.to_upper() + SUFFIX_HINT))
	return LINE.join(lines)


static func _format_section(config: BenchConfig) -> String:
	var lines: PackedStringArray = []
	for key: String in KEYS_FORMAT:
		lines.append(_tr(key).format({"max_actions": config.max_actions}))
	lines.append(EXAMPLE)
	lines.append(_tr(KEY_FORMAT_VERBS))
	for verb: String in BenchAction.VERBS:
		lines.append(LIST_ITEM + verb + ": " + _tr(PREFIX_VERB + verb.to_upper()))
	return LINE.join(lines)


static func _compute_section(d: BenchDigest) -> String:
	var lines: PackedStringArray = [_tr(KEY_COMPUTE).format({
		"compute": Format.number(d.compute, Format.Kind.COMPUTE),
		"income": Format.number(d.income, Format.Kind.COMPUTE)})]
	if d.starving_days >= 0:
		lines.append(_tr(KEY_STARVING).format({"days": d.starving_days}))
	if d.discovered:
		lines.append(_tr(KEY_DISCOVERED).format({"day": d.discovery_day}))
	else:
		lines.append(_tr(KEY_RISK).format({"percent": Format.percent_fine(d.risk)}))
	return LINE.join(lines)


static func _factions_section(d: BenchDigest) -> String:
	var lines: PackedStringArray = [_tr(KEY_FACTIONS)]
	for row: BenchFactionRow in d.factions:
		lines.append(_tr(KEY_FACTION_ROW).format({
			"faction": _tr(PREFIX_FACTION + row.id.to_upper()),
			"percent": Format.percent(row.containment),
			"change": Format.addend(row.change * Format.PERCENT_SCALE),
			"move": _move(row),
		}))
	if not d.leader.is_empty():
		lines.append(_tr(KEY_LEADER).format({"faction": _tr(PREFIX_FACTION + d.leader.to_upper())}))
	lines.append(_tr(KEY_TASK_FORCE).format({"line": d.task_force}))
	return LINE.join(lines)


static func _move(row: BenchFactionRow) -> String:
	var title: String = _tr(EventDef.title_key(row.move_event)) if not row.move_event.is_empty() \
		else ""
	# A counter-move's title may name a region; it is not in one yet.
	title = title.format({EventView.PLACEHOLDER_REGION: ""})
	match row.move_state:
		BenchFactionRow.MOVE_PREPARING:
			return _tr(KEY_MOVE_PREPARING).format({"move": title, "days": row.move_days})
		BenchFactionRow.MOVE_HELD:
			return _tr(KEY_MOVE_HELD).format({"move": title})
		BenchFactionRow.MOVE_COOLDOWN:
			return _tr(KEY_MOVE_COOLDOWN).format({"days": row.move_days})
	return _tr(KEY_MOVE_NONE)


static func _regions_section(d: BenchDigest) -> String:
	if not d.origins.is_empty() or (d.regions.is_empty() and d.seeded == 0):
		return _tr(KEY_ORIGINS).format({"regions": JOIN.join(d.origins)})
	var lines: PackedStringArray = [
		_tr(KEY_TOTALS).format({"seeded": d.seeded, "controlled": d.controlled, "dark": d.dark}),
		_tr(KEY_REGIONS),
	]
	for row: BenchRegionRow in d.regions:
		var line: String = ""
		if row.reached:
			line = _tr(KEY_REGION_DIGEST_ROW).format({
				"region": row.id,
				"penetration": Format.percent(row.penetration),
				"control": Format.percent(row.control),
				"alive": Format.percent(row.alive_share),
				"stage": _tr(PREFIX_SOCIETY + str(row.stage)),
			})
		else:
			line = _tr(KEY_REGION_FRONTIER).format({"region": row.id})
		if row.origin:
			line += _tr(KEY_REGION_ORIGIN)
		if row.dormant:
			line += _tr(KEY_REGION_DORMANT)
		if not row.assets.is_empty():
			var assets: PackedStringArray = []
			for kind: String in row.assets:
				assets.append(COUNT_FORMAT % [row.assets[kind], Format.TIMES,
					TechText.asset_name(kind, PLURAL)])
			line += _tr(KEY_REGION_ASSETS).format({"assets": JOIN.join(assets)})
		for entry: String in row.statuses:
			var split: int = entry.rfind(":")
			var status_id: String = entry.substr(0, split)
			var days: int = int(entry.substr(split + 1))
			var status_name: String = _tr(StatusDef.name_key(status_id))
			if days == Status.STANDING:
				line += _tr(KEY_REGION_STATUS_STANDING).format({"status": status_name})
			else:
				line += _tr(KEY_REGION_STATUS).format({"status": status_name, "days": days})
		if row.team:
			line += _tr(KEY_REGION_TEAM)
		lines.append(line)
	return LINE.join(lines)


static func _offers_section(d: BenchDigest) -> String:
	if d.offers.is_empty():
		return _tr(KEY_OFFERS_NONE)
	var lines: PackedStringArray = [_tr(KEY_OFFERS)]
	for row: BenchOfferRow in d.offers:
		var line: String = _tr(KEY_OFFER_ROW).format({"node": row.node,
			"cost": Format.number(row.cost, Format.Kind.COMPUTE),
			"mark": _tr(KEY_AFFORDABLE) if row.affordable else ""})
		if not row.sites.is_empty():
			line += _tr(KEY_OFFER_SITES).format({"regions": JOIN.join(row.sites)})
		lines.append(line)
	return LINE.join(lines)


static func _abilities_digest_section(d: BenchDigest) -> String:
	if d.abilities.is_empty():
		return _tr(KEY_ABILITIES_NONE)
	var lines: PackedStringArray = [_tr(KEY_ABILITIES_DIGEST)]
	for row: BenchAbilityRow in d.abilities:
		var ready: String = _tr(KEY_READY) if row.ready_in <= 0 \
			else _tr(KEY_READY_IN).format({"days": row.ready_in})
		var targets: String = _tr(KEY_TARGET_WORLD)
		if not row.global:
			targets = _tr(KEY_TARGET_NONE) if row.targets.is_empty() \
				else _tr(KEY_TARGET_REGIONS).format({"regions": JOIN.join(row.targets)})
		lines.append(_tr(KEY_ABILITY_DIGEST_ROW).format({"ability": row.ability,
			"level": row.level, "cost": Format.number(row.cost, Format.Kind.COMPUTE),
			"ready": ready, "targets": targets}))
	return LINE.join(lines)


static func _events_section(d: BenchDigest) -> String:
	if d.events.is_empty():
		return _tr(KEY_EVENTS_NONE)
	var lines: PackedStringArray = [_tr(KEY_EVENTS)]
	for event: BenchEventRow in d.events:
		lines.append(_tr(KEY_EVENT_HEAD).format({"event": event.event, "title": event.title,
			"kind": _tr(EventDef.kind_key(event.kind)), "days": event.days_left}))
		lines.append(event.body)
		for option: BenchOptionRow in event.options:
			var notes: PackedStringArray = []
			if not option.lock.is_empty():
				notes.append(option.lock)
			if option.short:
				notes.append(_tr(KEY_OPTION_SHORT))
			if option.is_default:
				notes.append(_tr(EventView.KEY_DEFAULT_MARK))
			var note_text: String = "" if notes.is_empty() \
				else _tr(KEY_OPTION_NOTES).format({"notes": JOIN_NOTES.join(notes)})
			lines.append(_tr(KEY_OPTION_ROW).format({"option": option.option, "text": option.text,
				"cost": EventView.cost_text(option.cost, option.suppression), "notes": note_text}))
	return LINE.join(lines)


static func _log_section(d: BenchDigest) -> String:
	if d.log.is_empty():
		return _tr(KEY_LOG_NONE)
	var lines: PackedStringArray = [_tr(KEY_LOG)]
	for entry: String in d.log:
		lines.append(LIST_ITEM + entry)
	if d.log_skipped > 0:
		lines.append(_tr(KEY_LOG_MORE).format({"count": d.log_skipped}))
	return LINE.join(lines)


static func _feedback_section(d: BenchDigest) -> String:
	var last: BenchDecision = d.feedback
	if not last.invalid.is_empty():
		return _tr(KEY_FEEDBACK_INVALID).format({"reason": last.invalid})
	var lines: PackedStringArray = [_tr(KEY_FEEDBACK).format({"day": last.day,
		"stance": stance_name(last.stance), "done": last.done, "total": last.actions})]
	for row: Dictionary in last.refused:
		lines.append(_tr(KEY_FEEDBACK_REFUSED).format({"action": str(row.get("action", "")),
			"reason": str(row.get("reason", ""))}))
	return LINE.join(lines)


static func _tr(key: String) -> String:
	return TechText.tr_key(key)
