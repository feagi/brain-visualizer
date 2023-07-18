extends MorphologyBase
class_name MorphologyComposite

var seed: Vector3i:
	get: return _seed
	set(v):
		_seed = v
		morphologyUpdated.emit(self)

var _seed: Vector3i

func _init(morphologyName: String, vec: Vector3i):
	super(morphologyName)
	seed = vec
