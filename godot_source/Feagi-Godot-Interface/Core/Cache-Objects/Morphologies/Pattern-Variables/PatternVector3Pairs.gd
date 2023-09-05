extends Object
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

func to_array_of_arrays() -> Array[Array]:
	return [_incoming.to_FEAGI_array(), _outgoing.to_FEAGI_array()]

func duplicate() -> PatternVector3Pairs:
	return PatternVector3Pairs.new(_incoming, _outgoing)
