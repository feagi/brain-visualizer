extends Object
class_name PatternVal
## PatternMorphology values can be ints, or "*" or "?". This can hold all of those

## All possible characters (non ints) a pattern var can be, as StringNames
const ACCEPTABLE_CHARS: Array[StringName] = [&"*", &"?"]

var data: Variant:
	get: return _data
	set(v): _verify(v)

var isInt: bool:
	get: return typeof(_data) == TYPE_INT

var isAny: bool:
	get: return _data == StringName("*")

var isMatchingOther: bool:
	get: return _data == StringName("?")

var as_StringName: StringName:
	get: return StringName(_data)

var _data: Variant # either StringName or int

func _init(input: Variant):
	_verify(input)

## Returns true if an input can be a PatternVar, otherwise returns false (attempting anyways will cause the value to be stored as int 0)
static func can_be_PatternVar(input: Variant) -> bool:
	if typeof(input) == TYPE_INT:
		return true
	if StringName(input) in ACCEPTABLE_CHARS or StringName(input).is_valid_int(): 
		return true
	return false

func _verify(input) -> void:
	if typeof(input) == TYPE_INT: # Optimization problem, theoretically dropping this top if statement will still allow this to work, but would it perform better?
		_data = input
		return
	var a = StringName(input)
	if a in ACCEPTABLE_CHARS:
		_data = a
		return
	_data = a.to_int() # if completely invalid, this will force it to 0

	
