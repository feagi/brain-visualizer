extends RefCounted
class_name PatternVector3Pairs
## Organizes PatternVector3s into in/out pairs, which is used in [PatternMorphology]

var incoming: PatternVector3:
	get: return _incoming.duplicate()
	set(v):
		_incoming = v.duplicate()
var outgoing: PatternVector3:
	get: return _outgoing.duplicate()
	set(v):
		_outgoing = v.duplicate()

var _incoming: PatternVector3
var _outgoing: PatternVector3

func _init(going_in: PatternVector3, going_out: PatternVector3):
	_incoming = going_in.duplicate()
	_outgoing = going_out.duplicate()

## Converts an array of arrays from the pattern morphologies into an array of PatternVector3Pairs
static func raw_pattern_nested_array_to_array_of_PatternVector3s(raw_array: Array) -> Array[PatternVector3Pairs]:
	# Preinit up here to reduce GC

	var pair: Array = [null, null]
	var output: Array[PatternVector3Pairs] = []
	for pair_in in raw_array:
		for pair_in_index in [0,1]:
			var vector_raw: Array = pair_in[pair_in_index]
			var X: PatternVal = PatternVal.new(vector_raw[0])
			var Y: PatternVal = PatternVal.new(vector_raw[1])
			var Z: PatternVal = PatternVal.new(vector_raw[2])
			pair[pair_in_index] = PatternVector3.new(X, Y, Z)
		output.append(PatternVector3Pairs.new(pair[0], pair[1]))
	return output

## Create empty [PatternVector3Pairs] (all values default to 0)
static func create_empty() -> PatternVector3Pairs:
	return PatternVector3Pairs.new(PatternVector3.create_empty(), PatternVector3.create_empty())

func to_array_of_arrays() -> Array[Array]:
	return [_incoming.to_FEAGI_array(), _outgoing.to_FEAGI_array()]

func duplicate() -> PatternVector3Pairs:
	return PatternVector3Pairs.new(_incoming.duplicate(), _outgoing.duplicate())


