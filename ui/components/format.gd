class_name Format
extends RefCounted
## Every number and every uppercased label the interface shows (spec
## ui-foundation.md §8.5).
##
## The locale decides the separators, so the same value reads `1,284.5` in
## English and `1.284,5` in German. Nothing formats a number by hand: a `%.1f`
## somewhere in a panel is a German bug waiting to happen.
##
## Never instantiated; a namespace of static functions.

enum Kind { PLAIN, COMPUTE, COMPACT, PERCENT, DAYS }

## U+2212. A hyphen is not a minus sign, and at 16 px the difference shows.
const MINUS: String = "−"
const LOCALE_DE: String = "de"

const KEY_MILLION: String = "UI_FMT_MILLION"
const KEY_BILLION: String = "UI_FMT_BILLION"

const MILLION: float = 1000000.0
const BILLION: float = 1000000000.0
const PERCENT_SCALE: float = 100.0

const GROUP_EN: String = ","
const DECIMAL_EN: String = "."
const GROUP_DE: String = "."
const DECIMAL_DE: String = ","
## German puts a space between the number and the unit; English does not.
const UNIT_GAP_DE: String = " "
const UNIT_GAP_EN: String = ""
const GROUP_SIZE: int = 3


## A value in the form its `Kind` asks for, in the current locale.
static func number(value: float, kind: Kind) -> String:
	var german: bool = is_german()
	var magnitude: float = absf(value)
	var text: String = ""
	match kind:
		Kind.PERCENT:
			text = _integer(roundi(magnitude * PERCENT_SCALE), german, true) \
				+ _unit_gap(german) + "%"
		Kind.DAYS:
			# A day number is a count, not a quantity: 1170, never 1,170.
			text = _integer(roundi(magnitude), german, false)
		Kind.COMPACT:
			text = _compact(magnitude, german)
		_:
			text = _decimal(magnitude, german)
	return (MINUS if value < 0.0 else "") + text


## A share in 0…1 as whole percent: 0.423 → "42%" (en) · "42 %" (de).
static func percent(value_01: float) -> String:
	return number(value_01, Kind.PERCENT)


## Uppercase for `TYPE_LABEL` (§3.2). Godot's `to_upper` leaves ß alone, which
## would put a lower-case letter in the middle of a button; German spells the
## capital of ß as SS. See PROGRESS.md, *Design questions for Fable*.
static func caps(text: String) -> String:
	return text.replace("ß", "ss").to_upper()


## Whether the current locale follows German number rules. Anything that is not
## German follows the English ones (§8.5).
static func is_german() -> bool:
	return TranslationServer.get_locale().begins_with(LOCALE_DE)


## Up to one decimal, a trailing `.0` dropped, thousands grouped.
static func _decimal(magnitude: float, german: bool) -> String:
	var scaled: int = roundi(magnitude * 10.0)
	@warning_ignore("integer_division")
	var whole: int = scaled / 10
	var tenth: int = scaled % 10
	var text: String = _integer(whole, german, true)
	if tenth != 0:
		text += (DECIMAL_DE if german else DECIMAL_EN) + str(tenth)
	return text


## §8.5: whole numbers below a million, one decimal and a unit above it.
static func _compact(magnitude: float, german: bool) -> String:
	if magnitude < MILLION:
		return _integer(roundi(magnitude), german, true)
	var unit: String = KEY_MILLION
	var scaled: float = magnitude / MILLION
	if magnitude >= BILLION:
		unit = KEY_BILLION
		scaled = magnitude / BILLION
	# `tr` belongs to `Object`; a static function asks the server itself.
	return _decimal(scaled, german) + " " + String(TranslationServer.translate(unit))


static func _integer(value: int, german: bool, grouped: bool) -> String:
	var digits: String = str(absi(value))
	if not grouped:
		return digits
	return _group(digits, GROUP_DE if german else GROUP_EN)


static func _group(digits: String, separator: String) -> String:
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % GROUP_SIZE == 0 and i > 0:
			out = separator + out
	return out


static func _unit_gap(german: bool) -> String:
	return UNIT_GAP_DE if german else UNIT_GAP_EN
