extends Object
class_name PatternVector

var x: PatternVar:
	get: return _data[0]
	set(v): _data[0] = v

var y: PatternVar:
	get: return _data[1]
	set(v): _data[1] = v

var z: PatternVar:
	get: return _data[2]
	set(v): _data[2] = v

var _data: Array

func _init(input):
	if input.is_class(PatternVector): _data = input._data; return
	_data = []
	for e in input:
		_data.append(PatternVar.new(e))
