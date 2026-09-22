class_name FloatBits
extends RefCounted
## A `float` as the 16 hex characters of its IEEE-754 bits — the form every float
## in a save and in `World.to_dict` is written in (core.md §5.1).
##
## Godot 4.7 cannot read a 64-bit float back out of JSON. `JSON.stringify` with
## `full_precision` writes every digit, but the parser loses the last bit of most
## values below 0.1 (91 % of them, measured at S1.8), and `String.to_float`,
## `str_to_var` and `String.num_scientific` lose the same bit.
## `PackedByteArray.encode_double` is the only exact path in the engine, so the
## bits are what a save stores. Everything else — whole numbers, ids, flags, the
## RNG strings — stays readable.

## Hex characters in one double.
const LENGTH: int = 16


## Big-endian and lower case, so the sign and the exponent lead and two
## neighbouring values still look alike in a diff.
static func to_hex(value: float) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var text: String = ""
	for i: int in range(7, -1, -1):
		text += "%02x" % bytes[i]
	return text


## Reads what `to_hex` wrote. Garbage in the string reads as some other number,
## never as an error: `is_readable` is what refuses a field.
static func from_hex(text: String) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	for i: int in 8:
		bytes.encode_u8(7 - i, text.substr(i * 2, 2).hex_to_int())
	return bytes.decode_double(0)


## The bit form **or** a plain JSON number, so that hand-written fixtures and
## anything written before this form keep loading.
static func from_variant(value: Variant) -> float:
	var type: int = typeof(value)
	if type == TYPE_FLOAT or type == TYPE_INT:
		return float(value)
	return from_hex(str(value))


## True for exactly what `from_variant` can read.
static func is_readable(value: Variant) -> bool:
	var type: int = typeof(value)
	if type == TYPE_FLOAT or type == TYPE_INT:
		return true
	if type != TYPE_STRING:
		return false
	var text: String = str(value)
	return text.length() == LENGTH and text.is_valid_hex_number(false)
