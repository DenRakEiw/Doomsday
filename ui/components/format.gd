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

enum Kind { PLAIN, COMPUTE, COMPACT, PERCENT, DAYS, PERCENT_FINE }

## U+2212. A hyphen is not a minus sign, and at 16 px the difference shows.
const MINUS: String = "−"
## U+00D7. A multiplier is not the letter x.
const TIMES: String = "×"
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
## How many places `_decimal` keeps, and the step `factor` asks one against.
const DECIMALS_ONE: int = 1
const DECIMALS_TWO: int = 2
const DECIMAL_STEP: float = 0.1


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
		Kind.PERCENT_FINE:
			# `percent_fine` as a kind, so a `StatBar` can read the risk out.
			text = _decimal(magnitude * PERCENT_SCALE, german) + _unit_gap(german) + "%"
		_:
			text = _decimal(magnitude, german)
	return (MINUS if value < 0.0 else "") + text


## A share in 0…1 as whole percent: 0.423 → "42%" (en) · "42 %" (de).
static func percent(value_01: float) -> String:
	return number(value_01, Kind.PERCENT)


## A share in 0…1 with one decimal: 0.0042 → "0.4%" (en) · "0,4 %" (de). The
## discovery risk of a quiet day is smaller than a whole percent and still has to
## read as a number rather than as zero (m3-screens §10.6).
static func percent_fine(value_01: float) -> String:
	var german: bool = is_german()
	var body: String = _decimal(absf(value_01) * PERCENT_SCALE, german)
	return (MINUS if value_01 < 0.0 else "") + body + _unit_gap(german) + "%"


## A multiplier as the detail pane writes it: `×1.3`, `×0.85`, `×2`. Two decimals
## only where one would round the number away (m3-screens §10.6). Modifier values
## are positive by validation, so there is no sign to carry.
static func factor(value: float) -> String:
	var decimals: int = DECIMALS_ONE
	if not is_equal_approx(value, snappedf(value, DECIMAL_STEP)):
		decimals = DECIMALS_TWO
	return TIMES + _decimal(absf(value), is_german(), decimals)


## A contribution to a sum, signed, up to two decimals: `+0.42`, `+1.5`, `+0`
## (opposition.md §9.2's pressure terms).
static func addend(value: float) -> String:
	var body: String = _decimal(absf(value), is_german(), DECIMALS_TWO)
	return (MINUS if value < 0.0 else "+") + body


## Uppercase for `TYPE_LABEL` (§3.2). Godot's `to_upper` leaves ß alone, which
## would put a lower-case letter in the middle of a button; German spells the
## capital of ß as SS. See PROGRESS.md, *Design questions for Fable*.
static func caps(text: String) -> String:
	return text.replace("ß", "ss").to_upper()


## Whether the current locale follows German number rules. Anything that is not
## German follows the English ones (§8.5).
static func is_german() -> bool:
	return TranslationServer.get_locale().begins_with(LOCALE_DE)


## Up to `decimals` places, trailing zeros dropped, thousands grouped.
static func _decimal(magnitude: float, german: bool, decimals: int = DECIMALS_ONE) -> String:
	var unit: int = 1
	for i: int in decimals:
		unit *= 10
	var scaled: int = roundi(magnitude * float(unit))
	@warning_ignore("integer_division")
	var whole: int = scaled / unit
	var fraction: int = scaled % unit
	var text: String = _integer(whole, german, true)
	if fraction == 0:
		return text
	var digits: String = str(fraction).pad_zeros(decimals)
	while digits.ends_with("0"):
		digits = digits.left(digits.length() - 1)
	return text + (DECIMAL_DE if german else DECIMAL_EN) + digits


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
