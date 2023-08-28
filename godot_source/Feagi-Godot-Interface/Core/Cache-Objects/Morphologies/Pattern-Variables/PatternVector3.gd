extends Object
class_name PatternVector3
## AN emulated Vector3 but using [PatternVal]

var x: PatternVal:
	get: return _data[0]
	set(v): _data[0] = v

var y: PatternVal:
	get: return _data[1]
	set(v): _data[1] = v

var z: PatternVal:
	get: return _data[2]
	set(v): _data[2] = v

var _data: Array[PatternVal]

func _init(X: PatternVal, Y: PatternVal, Z: PatternVal):
	_data = [X, Y, Z]
