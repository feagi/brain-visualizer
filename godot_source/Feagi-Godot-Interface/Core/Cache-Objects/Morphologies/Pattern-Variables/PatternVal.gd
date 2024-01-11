extends Object
class_name PatternVal
## PatternMorphology values can be ints, or "*" or "?". This can hold all of those

## All possible characters (non ints) a pattern var can be, as Strings
const ACCEPTABLE_CHARS: PackedStringArray = [&"*", &"?"]

var data: Variant:
	get: return _data
	set(v): _verify(v)

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
	if str(input) in ACCEPTABLE_CHARS or str(input).is_valid_int(): 
		return true
	return false

## Create an empty PatternVal (default to 0)
static func create_empty() -> PatternVal:
	return PatternVal.new(0)

## Mainly used when we wish to void crossing references
func duplicate() -> PatternVal:
	return PatternVal.new(_data)

func _verify(input: Variant) -> void:
	if typeof(input) == TYPE_INT: # Optimization problem, theoretically dropping this top if statement will still allow this to work, but would it perform better?
		_data = input
		return
	var a: StringName = str(input)
	if a in ACCEPTABLE_CHARS:
		_data = a
		return
	_data = a.to_int() # if completely invalid, this will force it to 0


