extends Object
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

# Do not define array type due to type mixing
func to_FEAGI_array() -> Array:
	return [x.data, y.data, z.data]

func duplicate() -> PatternVector3:
	return PatternVector3.new(self.x, self.y, self.z)
