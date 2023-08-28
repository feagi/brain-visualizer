extends Object
class_name PatternVal
## Some PatternMorphology values can be ints, or "*" or "?". This can hold all of those

var data: Variant:
	get: return _data
	set(v): Verify(v)

var isInt: bool:
	get: return typeof(_data) == TYPE_INT

var isAny: bool:
	get: return _data == StringName("*")

var isMatchingOther: bool:
	get: return _data == StringName("?")

var _data: Variant # either StringName or int

func _init(input: Variant):
	Verify(input)

func Verify(input) -> void:
	if typeof(input) == TYPE_INT:
		_data = input
	if input in ["*", "?"]:
		_data = StringName(input)
	@warning_ignore("assert_always_false")
	assert(false, "Invalid input for PatternVal!")
	
