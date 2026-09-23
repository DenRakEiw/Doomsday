class_name TechText
extends RefCounted
## What a technology node *does*, as sentences (spec m3-screens.md §3.6 item 5).
##
## The detail pane shows one line per modifier, flag and one-shot effect,
## generated from the definition — no node carries prose about its own numbers,
## and a content id never reaches the player: every id becomes a key here.
##
## Separate from the pane because it is pure text: a test can read these lines
## without putting a scene in the tree.
##
## Never instantiated; a namespace of static functions.

const KEY_MOD_MUL: String = "UI_TREE_MOD_MUL"
const KEY_MOD_ADD: String = "UI_TREE_MOD_ADD"
const KEY_INERT: String = "UI_TREE_INERT"
const KEY_SCOPE_MIN: String = "UI_TREE_SCOPE_MIN"
const KEY_SCOPE_MAX: String = "UI_TREE_SCOPE_MAX"
const KEY_SCOPE_RANGE: String = "UI_TREE_SCOPE_RANGE"
const KEY_SCOPE_REGION: String = "UI_TREE_SCOPE_REGION"
const KEY_SCOPE_CONTINENT: String = "UI_TREE_SCOPE_CONTINENT"

const PREFIX_STAT: String = "STAT_"
const PREFIX_FLAG: String = "FLAG_"
const PREFIX_EFFECT: String = "EFFECT_"
const PREFIX_ATTRIBUTE: String = "UI_ATTR_"
const PREFIX_REGION: String = "REGION_"
const PREFIX_CONTINENT: String = "CONTINENT_"
const PREFIX_TECH: String = "TECH_"
const SUFFIX_NAME: String = "_NAME"
const PREFIX_ASSET: String = "ASSET_"
const PREFIX_FACTION: String = "FACTION_"
const PREFIX_STATUS: String = "STATUS_"
const KEY_SCOPE_ASSET: String = "UI_TREE_SCOPE_ASSET"
const KEY_SCOPE_ASSET_MIN: String = "UI_TREE_SCOPE_ASSET_MIN"
## The two effects whose line depends on a field rather than on the id alone.
const KEY_GRANT_PER_HARDWARE: String = "EFFECT_COMPUTE_GRANT_PER_HARDWARE"
const KEY_FLAG_PERMANENT: String = "EFFECT_SET_FLAG_PERMANENT"
## What joins a list of names in one line.
const JOIN: String = ", "

## The effects whose `value` is a share of something, and therefore a percentage.
const EFFECT_SHARES: Array[String] = ["containment_rollback", "funding_reset", "harm_burst"]


## One modifier as a sentence: what it changes, by how much, and where.
static func modifier_line(modifier: ModifierDef, db: ContentDB) -> String:
	var key: String = KEY_MOD_MUL if modifier.op == ModifierDef.Op.MUL else KEY_MOD_ADD
	var value: String = Format.factor(modifier.value) if modifier.op == ModifierDef.Op.MUL \
		else _signed(modifier.value)
	var line: String = tr_key(key).format({
		"stat": tr_key(PREFIX_STAT + modifier.target.to_upper()),
		"value": value,
	})
	var scope: String = scope_line(modifier, db)
	if not scope.is_empty():
		line += " " + scope
	return _mark_inert(line, ModifierStack.INERT_TARGETS.has(modifier.target))


## The `where …` half of a modifier line, or "" for one that applies everywhere.
static func scope_line(modifier: ModifierDef, db: ContentDB) -> String:
	match modifier.scope_kind:
		ModifierDef.ScopeKind.ATTR:
			return _attribute_scope(modifier)
		ModifierDef.ScopeKind.REGION:
			var region: RegionDef = db.regions[modifier.scope_region]
			return tr_key(KEY_SCOPE_REGION).format(
				{"region": tr_key(PREFIX_REGION + region.id.to_upper())})
		ModifierDef.ScopeKind.CONTINENT:
			return tr_key(KEY_SCOPE_CONTINENT).format(
				{"continent": tr_key(PREFIX_CONTINENT + modifier.scope_continent.to_upper())})
		ModifierDef.ScopeKind.ASSET:
			if modifier.scope_min <= 1:
				return tr_key(KEY_SCOPE_ASSET).format(
					{"kind": asset_name(modifier.scope_asset)})
			return tr_key(KEY_SCOPE_ASSET_MIN).format({
				"kind": asset_name(modifier.scope_asset, modifier.scope_min),
				"count": modifier.scope_min,
			})
		_:
			return ""


static func flag_line(flag: String) -> String:
	return _mark_inert(tr_key(PREFIX_FLAG + flag.to_upper()),
		ModifierStack.INERT_FLAGS.has(flag))


## One one-shot effect as a sentence. The key is the effect's id, except where a
## field changes what the line says (`loop-mechanics.md` §17.6).
static func effect_line(effect: EffectDef) -> String:
	var line: String = tr_key(_effect_key(effect)).format(_effect_args(effect))
	return _mark_inert(line, effect.is_inert())


static func _effect_key(effect: EffectDef) -> String:
	if effect.effect == EffectDef.COMPUTE_GRANT and effect.per_hardware:
		return KEY_GRANT_PER_HARDWARE
	if effect.effect == EffectDef.SET_FLAG and effect.days <= 0:
		return KEY_FLAG_PERMANENT
	return PREFIX_EFFECT + effect.effect.to_upper()


## Every placeholder any effect line takes. A key that does not use one simply
## ignores it, so there is one table rather than a branch per effect.
static func _effect_args(effect: EffectDef) -> Dictionary:
	var value: String = Format.percent(effect.value) if EFFECT_SHARES.has(effect.effect) \
		else Format.number(effect.value, Format.Kind.COMPUTE)
	var names: Array[String] = []
	for status: String in effect.ids:
		names.append(tr_key(PREFIX_STATUS + status.to_upper() + SUFFIX_NAME))
	return {
		"value": value,
		"count": effect.count,
		"days": effect.days,
		"kind": asset_name(effect.kind, effect.count),
		"status": tr_key(PREFIX_STATUS + effect.status.to_upper() + SUFFIX_NAME),
		"statuses": JOIN.join(names),
		"faction": tr_key(PREFIX_FACTION + effect.faction.to_upper()),
	}


## An asset kind's name, singular or plural. Content ids never reach the player.
static func asset_name(kind: String, count: int = 1) -> String:
	if kind.is_empty():
		return ""
	var suffix: String = "_PLURAL" if count > 1 else SUFFIX_NAME
	return tr_key(PREFIX_ASSET + kind.to_upper() + suffix)


## The player-facing name of a node.
static func node_name(node_id: String) -> String:
	return tr_key(PREFIX_TECH + node_id.to_upper() + SUFFIX_NAME)


## The player-facing name of a modifier target (§17.6).
static func stat_name(target: String) -> String:
	return tr_key(PREFIX_STAT + target.to_upper())


## One modifier's number the way the detail pane writes it: a factor for a
## `mul`, a signed number for an `add` (`loop-mechanics.md` §16.2).
static func modifier_value(modifier: ModifierDef) -> String:
	if modifier.op == ModifierDef.Op.MUL:
		return Format.factor(modifier.value)
	return _signed(modifier.value)


## `tr` belongs to `Object`; a static function asks the server itself.
static func tr_key(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _attribute_scope(modifier: ModifierDef) -> String:
	var attribute: String = tr_key(PREFIX_ATTRIBUTE + modifier.scope_attr.to_upper())
	var has_min: bool = modifier.scope_min > RegionDef.TIER_MIN
	var has_max: bool = modifier.scope_max < RegionDef.TIER_MAX
	if has_min and has_max:
		return tr_key(KEY_SCOPE_RANGE).format({
			"attr": attribute,
			"min": modifier.scope_min,
			"max": modifier.scope_max,
		})
	if has_max:
		return tr_key(KEY_SCOPE_MAX).format({"attr": attribute, "tier": modifier.scope_max})
	return tr_key(KEY_SCOPE_MIN).format({"attr": attribute, "tier": modifier.scope_min})


## A target, flag or effect no system reads yet says so, and stops saying it the
## day its system lands — the constant is the only thing that changes (§3.6).
static func _mark_inert(line: String, inert: bool) -> String:
	return "%s %s" % [line, tr_key(KEY_INERT)] if inert else line


static func _signed(value: float) -> String:
	var body: String = Format.number(value, Format.Kind.PLAIN)
	return ValueLabel.PLUS + body if value > 0.0 else body
