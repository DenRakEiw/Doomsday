class_name PseudoLocale
extends RefCounted
## UI.md §4 "Localisation": a pseudo-translation that makes every string longer
## and marks where it starts and ends, so a clipped or overflowing text shows
## before a translator's does.
##
## `[Ñéẃ rüñ~~~~]` — the brackets show whether the whole text is on screen, the
## accents whether the font has them, the tildes stand in for the longer words
## of a real translation. Placeholders and markup are kept as they are, so every
## `format()` still fills in.
##
## While it is on it *replaces* the English translation: the locale stays `en`,
## numbers are formatted as English, and turning it off puts the original back.
## The source rows come from `StringTable`, so this is a development switch —
## an exported build has no CSV to read and stays as it is.

const LOCALE: String = "en"
## German runs about a third longer than English; the pseudo-locale is longer
## still, so that what fits it fits any language we are likely to add.
const EXPANSION: float = 0.4
const PAD: String = "~"
const OPEN: String = "["
const CLOSE: String = "]"
## Latin-1 only: both fonts carry it, and a missing glyph here would be a false
## alarm, not a finding.
const ACCENTS: Dictionary[String, String] = {
	"a": "á", "e": "é", "i": "í", "o": "ö", "u": "ü", "n": "ñ", "c": "ç", "y": "ý",
	"A": "Å", "E": "É", "I": "Í", "O": "Ö", "U": "Ü", "N": "Ñ", "C": "Ç", "Y": "Ý",
}
## What is copied through untouched: a named placeholder, a BBCode tag.
const VERBATIM_PATTERN: String = "\\{[a-z_][a-z0-9_]*\\}|\\[/?[a-z_]+[^\\]]*\\]"

static var _original: Translation = null
static var _pseudo: Translation = null


static func is_enabled() -> bool:
	return _pseudo != null


## One text, pseudo-translated. An empty text stays empty: an empty cell is a
## finding for the string check, not something to dress up.
static func text(source: String) -> String:
	if source.is_empty():
		return source
	var regex: RegEx = RegEx.create_from_string(VERBATIM_PATTERN)
	var out: String = ""
	var visible: int = 0
	var at: int = 0
	for hit: RegExMatch in regex.search_all(source):
		var plain: String = source.substr(at, hit.get_start() - at)
		out += _accented(plain) + hit.get_string()
		visible += plain.length()
		at = hit.get_end()
	var tail: String = source.substr(at)
	out += _accented(tail)
	visible += tail.length()
	return OPEN + out + PAD.repeat(ceili(float(visible) * EXPANSION)) + CLOSE


## A translation of every English row. Keys come from the table, texts from it
## too: the imported translation is optimised and cannot list its messages.
static func translation(table: Dictionary[String, PackedStringArray]) -> Translation:
	var out: Translation = Translation.new()
	out.locale = LOCALE
	for key: String in table:
		out.add_message(StringName(key), text(table[key][StringTable.COLUMN_EN]))
	return out


## Swaps the English translation for the pseudo one. Whether the texts on screen
## follow is the caller's business: `Settings` sets the locale, which notifies.
static func enable() -> bool:
	if is_enabled():
		return true
	var duplicates: Array[String] = []
	var table: Dictionary[String, PackedStringArray] = StringTable.read(StringTable.PATH,
		duplicates)
	if table.is_empty():
		return false
	_original = TranslationServer.get_translation_object(LOCALE)
	if _original != null:
		TranslationServer.remove_translation(_original)
	_pseudo = translation(table)
	TranslationServer.add_translation(_pseudo)
	return true


static func disable() -> void:
	if not is_enabled():
		return
	TranslationServer.remove_translation(_pseudo)
	if _original != null:
		TranslationServer.add_translation(_original)
	_pseudo = null
	_original = null


static func _accented(plain: String) -> String:
	var out: String = ""
	for i: int in plain.length():
		var character: String = plain[i]
		out += str(ACCENTS.get(character, character))
	return out
