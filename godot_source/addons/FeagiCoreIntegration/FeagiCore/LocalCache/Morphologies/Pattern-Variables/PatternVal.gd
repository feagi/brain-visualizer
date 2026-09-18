extends RefCounted
class_name PatternVal
## PatternMorphology values can be ints, or wildcards/directional patterns.
## Supports: integers, "*", "?", "!", "?+", "?-", "?+=", "?-=", "?+N", "?-N", "?-A:?+B", "N..M"

## Single-char pattern symbols
const SINGLE_CHAR_PATTERNS: PackedStringArray = [&"*", &"?", &"!"]

## Direction-only patterns (no numeric component)
const DIRECTION_PATTERNS: PackedStringArray = [&"?+", &"?-", &"?+=", &"?-="]

var data: Variant:
	get: return _data
	set(v): 
		_verify(v)


var isInt: bool:
	get: return typeof(_data) == TYPE_INT

var isAny: bool:
	get: return str(_data) == "*"

var isMatchingOther: bool:
	get: return str(_data) == "?"

var isMatchingNot: bool:
	get: return str(_data) == "!"

var isDirectionPositive: bool:
	get: return str(_data) == "?+"

var isDirectionNegative: bool:
	get: return str(_data) == "?-"

var isDirectionPositiveInclusive: bool:
	get: return str(_data) == "?+="

var isDirectionNegativeInclusive: bool:
	get: return str(_data) == "?-="

## True if value is any directional pattern (exclusive or inclusive)
var isDirectional: bool:
	get: return str(_data) in DIRECTION_PATTERNS

## True if value is an offset pattern like "?+3" or "?-2"
var isOffset: bool:
	get: return _is_offset_pattern(str(_data))

## True if value is a range pattern like "?-1:?+1"
var isRange: bool:
	get: return _is_range_pattern(str(_data))

## True if value is an absolute range like "1..98"
var isAbsoluteRange: bool:
	get: return _is_absolute_range_pattern(str(_data))

## True if value is any source-relative pattern (not int, not *, not exact, not N..M)
var isRelative: bool:
	get: return isMatchingOther or isMatchingNot or isDirectional or isOffset or isRange

var as_StringName: StringName:
	get: return str(_data)

## False when construction input was not a legal token. Never coerce that to 0.
var is_parse_valid: bool:
	get: return _parse_ok

var _data: Variant = 0 # either StringName or int
var _parse_ok: bool = false

func _init(input: Variant):
	_verify(input)

## Returns true if an input can be a PatternVal
static func can_be_PatternVal(input: Variant) -> bool:
	if input is int:
		return true
	var s: String = str(input)
	if s in SINGLE_CHAR_PATTERNS:
		return true
	if s in DIRECTION_PATTERNS:
		return true
	if s.is_valid_int():
		return true
	if _is_offset_pattern_static(s):
		return true
	if _is_range_pattern_static(s):
		return true
	if _is_absolute_range_pattern_static(s):
		return true
	return false

static func are_pattern_vals_equal(A: PatternVal, B: PatternVal) -> bool:
	return A.data == B.data

## Create an empty PatternVal (default to 0)
static func create_empty() -> PatternVal:
	return PatternVal.new(0)


## Explicit invalid token. Apply/create must refuse this instead of writing 0.
static func create_invalid() -> PatternVal:
	var invalid: PatternVal = PatternVal.new(0)
	invalid._parse_ok = false
	return invalid


## JSON-safe token: ints stay ints, ranges/symbols stay String (not StringName).
func to_feagi_token() -> Variant:
	if !_parse_ok:
		return null
	if isInt:
		return int(_data)
	return String(as_StringName)

## Check if string is an offset pattern like "?+3" or "?-2"
static func _is_offset_pattern_static(s: String) -> bool:
	if !s.begins_with("?"):
		return false
	var rest: String = s.substr(1)
	if rest.is_empty():
		return false
	if rest in ["+", "-", "+=", "-="]:
		return false
	if rest.contains(":"):
		return false
	return rest.is_valid_int()

## Check if string is a range pattern like "?-1:?+1"
static func _is_range_pattern_static(s: String) -> bool:
	if !s.contains(":"):
		return false
	var parts: PackedStringArray = s.split(":")
	if parts.size() != 2:
		return false
	return _is_offset_pattern_static(parts[0]) and _is_offset_pattern_static(parts[1])

## Check if string is an absolute range like "1..98"
static func _is_absolute_range_pattern_static(s: String) -> bool:
	var idx: int = s.find("..")
	if idx < 0:
		return false
	if s.find("..", idx + 2) >= 0:
		return false
	var lo: String = s.substr(0, idx)
	var hi: String = s.substr(idx + 2)
	return lo.is_valid_int() and hi.is_valid_int()

func _is_offset_pattern(s: String) -> bool:
	return PatternVal._is_offset_pattern_static(s)

func _is_range_pattern(s: String) -> bool:
	return PatternVal._is_range_pattern_static(s)

func _is_absolute_range_pattern(s: String) -> bool:
	return PatternVal._is_absolute_range_pattern_static(s)

func _verify(input: Variant) -> void:
	_parse_ok = false
	if input is StringName:
		var s: String = String(input)
		if s.is_valid_int():
			_data = s.to_int()
			_parse_ok = true
			return
		if input in SINGLE_CHAR_PATTERNS or input in DIRECTION_PATTERNS:
			_data = input
			_parse_ok = true
			return
		if _is_offset_pattern(s) or _is_range_pattern(s) or _is_absolute_range_pattern(s):
			_data = input
			_parse_ok = true
			return
		return
	if input is String:
		if input.is_valid_int():
			_data = input.to_int()
			_parse_ok = true
			return
		var sn: StringName = StringName(input)
		if sn in SINGLE_CHAR_PATTERNS or sn in DIRECTION_PATTERNS:
			_data = sn
			_parse_ok = true
			return
		if _is_offset_pattern(input) or _is_range_pattern(input) or _is_absolute_range_pattern(input):
			_data = StringName(input)
			_parse_ok = true
			return
		return
	if input is int:
		_data = input
		_parse_ok = true
		return
	if input is float and is_equal_approx(float(input), round(float(input))):
		_data = int(input)
		_parse_ok = true
		return
	# Do not int() arrays, null, or unknown types. That is how N..M became 0.

func duplicate() -> PatternVal:
	if !_parse_ok:
		return PatternVal.create_invalid()
	return PatternVal.new(_data)
