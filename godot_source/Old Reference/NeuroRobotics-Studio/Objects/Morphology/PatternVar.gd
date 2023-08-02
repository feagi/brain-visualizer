extends Object
class_name PatternVar
# Some morpholgy values can be ints, or "*" or "?". THis can hold all of those

var data:
	get: return _data
	set(v): Verify(v)

var isInt: bool:
	get: return typeof(_data) == TYPE_INT

var isAny: bool:
	get: return _data == StringName("*")

var isMatchingOther: bool:
	get: return _data == StringName("?")

var _data # either StringName or int

func _init(input):
	Verify(input)

func Verify(input) -> void:
	if typeof(input) == TYPE_INT: _data = input
	if input in ["*", "?"]: _data = StringName(input)
	@warning_ignore("assert_always_false")
	assert(false, "Invalid input for PatternVar!")
	
