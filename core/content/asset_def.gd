class_name AssetDef
extends RefCounted
## One kind of asset and what standing in a region is worth (`loop-mechanics.md`
## §6.1).
##
## An asset is a thing the agent has *on the ground*: a fleet of machines, a lab,
## a tap, an office. The kind's modifiers are the base effects every asset of it
## carries; the loader scopes each one `{"asset": kind}`, so a modifier applies
## exactly where at least one of them stands and nowhere else. The sources are
## always active — the scope does the gating (§6.2).
##
## There are exactly four kinds and content may not add a fifth: an asset is a
## verb of the interface (a glyph, a row, a marker), not an open vocabulary.

const KIND_FLEET: String = "fleet"
const KIND_LAB: String = "lab"
const KIND_TAP: String = "tap"
const KIND_OFFICE: String = "office"
## Also the drawing order of the marker row and of the region panel's rows.
const KINDS: Array[String] = ["fleet", "lab", "tap", "office"]

## The fields `assets.json` allows per entry.
const KEYS: Array[String] = ["kind", "watched_by", "glyph", "modifiers"]
## The root list of `assets.json`.
const ROOT_KEY: String = "assets"

var kind: String
## Every one scoped `{"asset": kind}` by the loader (§6.3).
var modifiers: Array[ModifierDef] = []
## The factions that notice this kind. Read by S4.4's per-faction Footprint.
var watched_by: Array[String] = []
## A name in `Glyphs.ASSET_NAMES` (§16.3.2).
var glyph: String


## The localisation key of a kind's name, or of its plural.
static func name_key(asset_kind: String) -> String:
	return "ASSET_%s_NAME" % asset_kind.to_upper()


static func plural_key(asset_kind: String) -> String:
	return "ASSET_%s_PLURAL" % asset_kind.to_upper()
