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
		_:
			return ""


static func flag_line(flag: String) -> String:
	return _mark_inert(tr_key(PREFIX_FLAG + flag.to_upper()),
		ModifierStack.INERT_FLAGS.has(flag))


static func effect_line(effect: PurchaseEffectDef) -> String:
	var value: String = Format.percent(effect.value) if EFFECT_SHARES.has(effect.effect) \
		else Format.number(effect.value, Format.Kind.COMPUTE)
	var line: String = tr_key(PREFIX_EFFECT + effect.effect.to_upper()).format({"value": value})
	return _mark_inert(line, PurchaseEffectDef.INERT_EFFECTS.has(effect.effect))


## The player-facing name of a node.
static func node_name(node_id: String) -> String:
	return tr_key(PREFIX_TECH + node_id.to_upper() + SUFFIX_NAME)


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
