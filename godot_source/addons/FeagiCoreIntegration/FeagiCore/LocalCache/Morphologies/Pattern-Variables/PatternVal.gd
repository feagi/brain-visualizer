extends Resource
class_name PatternVal
## PatternMorphology values can be ints, or "*" or "?". This can hold all of those

## All possible characters (non ints) a pattern var can be, as Strings
const ACCEPTABLE_CHARS: PackedStringArray = [&"*", &"?"]

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

var as_StringName: StringName:
	get: return str(_data)

var _data: Variant = 0 # either StringName or int

func _init(input: Variant):
	_verify(input)

## Returns true if an input can be a PatternVal, otherwise returns false (attempting anyways will cause the value to be stored as int 0)
static func can_be_PatternVal(input: Variant) -> bool:
	if input is int:
		return true
	if str(input) in ACCEPTABLE_CHARS or str(input).is_valid_int(): 
		return true
	return false

static func are_pattern_vals_equal(A: PatternVal, B: PatternVal) -> bool:
	return A.data == B.data

## Create an empty PatternVal (default to 0)
static func create_empty() -> PatternVal:
	return PatternVal.new(0)

func _verify(input: Variant) -> void:
	if input is int:
		_data = input
		return
	if input is StringName:
		if input.is_valid_int():
			_data = input.to_int()
			return
		if input in ACCEPTABLE_CHARS:
			_data = input
			return
		return
	if input is String:
		if input.is_valid_int():
			_data = input.to_int()
			return
		if StringName(input) in ACCEPTABLE_CHARS:
			_data = StringName(input)
			return
		return


