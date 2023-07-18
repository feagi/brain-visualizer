extends MorphologyBase
class_name MorphologyPatterns

var vector1: Vector3:
	get: return _vector1
	set(v):
		_vector1 = v
		morphologyUpdated.emit(self)
	
var vector2: Vector3:
	get: return _vector2
	set(v):
		_vector2 = v
		morphologyUpdated.emit(self)

var _vector1: Vector3
var _vector2: Vector3

func _init(morphologyName: String, vec1: Vector3, vec2: Vector3):
	super(morphologyName)
	_vector1 = vec1
	vector2 = vec2
