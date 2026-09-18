extends RefCounted
class_name PatternVector3
## AN emulated Vector3 but using [PatternVal]

var x: PatternVal:
	get: return _data[0].duplicate()
	set(v): _data[0] = v.duplicate()

var y: PatternVal:
	get: return _data[1].duplicate()
	set(v): _data[1] = v.duplicate()

var z: PatternVal:
	get: return _data[2].duplicate()
	set(v): _data[2] = v.duplicate()

var _data: Array[PatternVal]

func _init(X: PatternVal, Y: PatternVal, Z: PatternVal):
	_data = [X, Y, Z]

## Create empty [PatternVector3] (all values default to 0)
static func create_empty() -> PatternVector3:
	return PatternVector3.new(PatternVal.create_empty(), PatternVal.create_empty(),
	PatternVal.create_empty())

func all_tokens_parse_valid() -> bool:
	return _data[0].is_parse_valid and _data[1].is_parse_valid and _data[2].is_parse_valid


# Do not type the array: ints and strings are mixed on purpose.
func to_FEAGI_array() -> Array:
	return [_data[0].to_feagi_token(), _data[1].to_feagi_token(), _data[2].to_feagi_token()]

func duplicate() -> PatternVector3:
	return PatternVector3.new(x.duplicate(), y.duplicate(), z.duplicate())

