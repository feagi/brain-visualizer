extends MorphologyBase
class_name MorphologyVectors

var vector: Vector3i:
	get: return _vector
	set(v):
		_vector = v
		morphologyUpdated.emit(self)

var _vector: Vector3i


func _init(morphologyName: String, vec: Vector3i):
	super(morphologyName)
	vector = vec
